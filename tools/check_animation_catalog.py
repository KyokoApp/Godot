"""Ukur metrik animasi UAL langsung dari berkas GLB (tanpa engine Godot).

Dipakai sebagai gerbang lint di CI supaya kelengkapan katalog dan klaim
"tidak ada kaki meluncur" bisa diverifikasi tanpa menjalankan engine.
"""
import json
import math
import re
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "project/src/game/animation/catalog.gd"
GLB = {
    "UAL1": ROOT / "project/assets/mannequin/UAL1_Standard.glb",
    "UAL2": ROOT / "project/assets/combat/UAL2_Standard.glb",
}
FLAGS = {"loop", "once", "hold", "gait"}
# Rentang kecepatan alami yang diharapkan (m/s), hasil ukur ulang tiap perubahan.
BANDS = {
    "Walk_Loop": (0.7, 1.6),
    "Jog_Fwd_Loop": (2.0, 3.6),
    "Sprint_Loop": (2.4, 4.6),
    "Crouch_Fwd_Loop": (0.3, 1.3),
    "Walk_Carry_Loop": (0.3, 1.3),
    "Zombie_Walk_Fwd_Loop": (0.5, 1.8),
    "Swim_Fwd_Loop": (0.02, 2.0),
}
SAMPLE_RATE = 30.0
# Akhiran yang dibuang importer glTF dari nama animasi di AnimationPlayer.
LOOP_SUFFIX = "_Loop"
# Klip ber-flag loop/gait yang namanya TIDAK berakhiran "_Loop" (loop-nya harus
# dinyalakan manual oleh aurelia_visual.gd::_configure_clips).
SILENT_LOOPS = ["A_TPose", "Sword_Idle", "Pistol_Aim_Down", "Pistol_Aim_Neutral",
                "Pistol_Aim_Up"]

COMPONENTS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
FORMATS = {5120: "b", 5121: "B", 5122: "h", 5123: "H", 5125: "I", 5126: "f"}


def load_glb(path):
    data = path.read_bytes()
    _magic, _version, length = struct.unpack("<III", data[:12])
    offset, js, binary = 12, None, b""
    while offset < length:
        chunk_length, chunk_type = struct.unpack("<II", data[offset:offset + 8])
        offset += 8
        chunk = data[offset:offset + chunk_length]
        offset += chunk_length
        if chunk_type == 0x4E4F534A:
            js = json.loads(chunk.decode("utf-8"))
        elif chunk_type == 0x004E4942:
            binary = chunk
    return js, binary


def read_accessor(js, binary, index):
    accessor = js["accessors"][index]
    view = js["bufferViews"][accessor["bufferView"]]
    fmt = FORMATS[accessor["componentType"]]
    count = accessor["count"]
    size = COMPONENTS[accessor["type"]]
    stride = view.get("byteStride") or struct.calcsize("<" + fmt) * size
    start = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
    out = []
    for i in range(count):
        values = struct.unpack_from("<" + fmt * size, binary, start + i * stride)
        out.append(values[0] if size == 1 else values)
    return out


def quat_slerp(a, b, t):
    dot = sum(x * y for x, y in zip(a, b))
    if dot < 0.0:
        b = tuple(-x for x in b)
        dot = -dot
    if dot > 0.9995:
        result = [x + t * (y - x) for x, y in zip(a, b)]
        norm = math.sqrt(sum(x * x for x in result)) or 1.0
        return tuple(x / norm for x in result)
    theta = math.acos(max(-1.0, min(1.0, dot)))
    sin_theta = math.sin(theta)
    return tuple((a[i] * math.sin((1 - t) * theta) + b[i] * math.sin(t * theta)) / sin_theta
                 for i in range(4))


def quat_matrix(q):
    x, y, z, w = q
    return [
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ]


def mat_mul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def mat_apply(m, v):
    return tuple(sum(m[i][k] * v[k] for k in range(3)) for i in range(3))


class Clip:
    def __init__(self, js, binary, index):
        self.js = js
        self.binary = binary
        animation = js["animations"][index]
        self.name = animation.get("name", "Anim_%d" % index)
        self.channels = []
        self.length = 0.0
        for channel in animation["channels"]:
            sampler = animation["samplers"][channel["sampler"]]
            times = read_accessor(js, binary, sampler["input"])
            values = read_accessor(js, binary, sampler["output"])
            self.length = max(self.length, times[-1] if times else 0.0)
            self.channels.append({
                "node": channel["target"]["node"],
                "path": channel["target"]["path"],
                "times": times,
                "values": values,
                "step": sampler.get("interpolation", "LINEAR") == "STEP",
            })

    def sample(self, channel, time):
        times, values = channel["times"], channel["values"]
        if not times:
            return None
        if time <= times[0]:
            return values[0]
        if time >= times[-1]:
            return values[-1]
        low, high = 0, len(times) - 1
        while high - low > 1:
            mid = (low + high) // 2
            if times[mid] <= time:
                low = mid
            else:
                high = mid
        span = times[high] - times[low]
        t = 0.0 if span <= 0.0 else (time - times[low]) / span
        if channel["step"]:
            t = 0.0
        a, b = values[low], values[high]
        if channel["path"] == "rotation":
            return quat_slerp(a, b, t)
        if isinstance(a, (int, float)):
            return a + (b - a) * t
        return tuple(x + (y - x) * t for x, y in zip(a, b))

    def locals_at(self, time):
        out = {}
        for channel in self.channels:
            out.setdefault(channel["node"], {})[channel["path"]] = self.sample(channel, time)
        return out


def evaluate(js, clip, node, time, cache):
    """Transform global (rotasi, translasi) satu node pada waktu tertentu."""
    key = (node, time)
    if key in cache:
        return cache[key]
    local = clip.locals_at(time).get(node, {})
    definition = js["nodes"][node]
    rotation = local.get("rotation", tuple(definition.get("rotation", (0.0, 0.0, 0.0, 1.0))))
    translation = local.get("translation", tuple(definition.get("translation", (0.0, 0.0, 0.0))))
    matrix = quat_matrix(rotation)
    parent = definition.get("children") and definition.get("parent")
    if parent is None:
        # Cari parent lewat daftar children (glTF tidak menyimpan parent).
        parent = PARENTS.get(node)
    if parent is None:
        result = (matrix, translation)
    else:
        parent_rotation, parent_translation = evaluate(js, clip, parent, time, cache)
        result = (mat_mul(parent_rotation, matrix),
                  tuple(parent_translation[i] + mat_apply(parent_rotation, translation)[i]
                        for i in range(3)))
    cache[key] = result
    return result


PARENTS = {}


def build_parents(js):
    PARENTS.clear()
    for index, node in enumerate(js.get("nodes", [])):
        for child in node.get("children", []):
            PARENTS[child] = index


def measure(js, clip, time):
    cache = {}
    out = {}
    for name in ("foot_l", "foot_r"):
        index = next((i for i, n in enumerate(js["nodes"]) if n.get("name") == name), None)
        if index is None:
            continue
        _rotation, translation = evaluate(js, clip, index, time, cache)
        out[name] = translation
    return out


def measure_clip(js, clip, rate=SAMPLE_RATE):
    steps = max(int(math.ceil(clip.length * rate)) + 1, 2)
    min_y = math.inf
    bounds = {"foot_l": [math.inf, -math.inf], "foot_r": [math.inf, -math.inf]}
    for step in range(steps):
        time = min(clip.length, step / rate)
        pose = measure(js, clip, time)
        for name, point in pose.items():
            min_y = min(min_y, point[1])
            bounds[name][0] = min(bounds[name][0], point[2])
            bounds[name][1] = max(bounds[name][1], point[2])
    stride = 0.0
    for name in bounds:
        low, high = bounds[name]
        if low < math.inf:
            stride += (high - low) * 0.5
    natural = 2.0 * stride / clip.length if clip.length > 0 else 0.0
    return {"length": clip.length, "stride": stride, "natural_speed": natural,
            "foot_min_y": min_y if min_y < math.inf else 0.0}


def catalog_entries():
    text = CATALOG.read_text(encoding="utf-8")
    pattern = re.compile(
        r'\["([A-Za-z0-9_]+)",\s*"([^"]*)",\s*(UAL[12])\s*,\s*"([a-z]+)",\s*\n?\s*"([^"]*)"\]')
    return [{"name": m.group(1), "label": m.group(2), "source": m.group(3),
             "flags": m.group(4), "desc": m.group(5)} for m in pattern.finditer(text)]


def main():
    problems = []
    clips = {}
    for source, path in GLB.items():
        js, binary = load_glb(path)
        build_parents(js)
        clips[source] = [Clip(js, binary, i) for i in range(len(js["animations"]))]
        clips[source + "_js"] = js
        print("%s: %d klip" % (source, len(clips[source])))
    entries = catalog_entries()
    names = [entry["name"] for entry in entries]
    if len(entries) != 85 or len(set(names)) != 85:
        problems.append("katalog tidak berisi 85 nama unik (%d entri, %d unik)"
                        % (len(entries), len(set(names))))
    for entry in entries:
        if entry["flags"] not in FLAGS:
            problems.append("flag tidak dikenal: %s -> %s" % (entry["name"], entry["flags"]))
        if len(entry["label"]) < 2 or len(entry["desc"]) < 10:
            problems.append("label/keterangan terlalu pendek: " + entry["name"])
    by_source = {source: [c.name for c in clips[source]] for source in GLB}
    entry_source = {entry["name"]: entry["source"] for entry in entries}
    # Importer glTF Godot membuang kata "loop"/"cycle" di akhir nama animasi, jadi
    # nama di AnimationPlayer = nama berkas tanpa "_Loop". Nama runtime itu WAJIB
    # unik: kalau dua klip menyusut jadi nama sama, satu klip akan hilang.
    runtime = {}
    for name in names:
        short = name[:-len(LOOP_SUFFIX)] if name.endswith(LOOP_SUFFIX) else name
        runtime.setdefault(short, []).append(name)
    for short in sorted(runtime):
        if len(runtime[short]) > 1:
            problems.append("nama runtime bentrok setelah sufiks dibuang: %s -> %s"
                            % (short, ", ".join(runtime[short])))
    # Klip yang loop-nya tidak ditandai "_Loop" harus disetel eksplisit di kode
    # (_configure_clips), jadi pastikan daftarnya tetap kecil dan terpantau.
    silent_loops = [e["name"] for e in entries
                    if e["flags"] in ("loop", "gait") and not e["name"].endswith(LOOP_SUFFIX)]
    if silent_loops != SILENT_LOOPS:
        problems.append("klip loop tanpa sufiks berubah: %s (harus %s)"
                        % (", ".join(silent_loops), ", ".join(SILENT_LOOPS)))
    for source in GLB:
        for clip in by_source[source]:
            if clip not in entry_source:
                problems.append("klip %s hilang dari katalog (%s)" % (clip, source))
            elif clip not in by_source[entry_source[clip]]:
                problems.append("sumber salah untuk %s: %s" % (clip, entry_source[clip]))
    for name in names:
        if name not in by_source["UAL1"] and name not in by_source["UAL2"]:
            problems.append("nama katalog tidak ada di berkas: " + name)
    # Ukur ulang kecepatan alami gait dan bandingkan dengan rentang yang dijaga.
    measured = {}
    for source in GLB:
        js = clips[source + "_js"]
        for clip in clips[source]:
            if entry_source.get(clip.name) in ("loop", "gait") or clip.name in BANDS:
                measured[clip.name] = measure_clip(js, clip)
    for name, band in BANDS.items():
        if name not in measured:
            problems.append("klip gait tidak terukur: " + name)
            continue
        speed = measured[name]["natural_speed"]
        if not (band[0] <= speed <= band[1]):
            problems.append("kecepatan alami %s di luar rentang %.2f-%.2f: %.2f m/s"
                            % (name, band[0], band[1], speed))
        print("  %-22s %.2fs langkah %.2fm alami %.2f m/s kaki %.3fm"
              % (name, measured[name]["length"], measured[name]["stride"],
                 speed, measured[name]["foot_min_y"]))
    if problems:
        for problem in problems:
            print("::error::" + problem)
        raise SystemExit("Katalog animasi GAGAL: %d masalah" % len(problems))
    print("Katalog animasi: OK (%d klip, %d gait terukur)" % (len(entries), len(BANDS)))


if __name__ == "__main__":
    main()
