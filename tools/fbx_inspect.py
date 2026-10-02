#!/usr/bin/env python3
"""Periksa isi FBX biner tanpa Godot.

Kenapa ada: banyak keputusan material/kerangka avatar Aurelia hanya bisa
dijawab dari berkasnya sendiri (paket `aurelia-debug/`):
  * material mana dipakai poligon mana (`LayerElementMaterial` + koneksi),
  * tekstur resmi tiap material (lihat juga `aurelia-debug/Materials/*.json`),
  * tulang tambahan (kain, rambut, aksesori) yang TIDAK berawalan `Bip001`,
  * bobot kulit per tulang (Cluster) — dipakai untuk mengukur tebal leher,
    lengan, dll. dari geometrinya.

Pakai:
    python3 tools/fbx_inspect.py bones   <file.fbx>
    python3 tools/fbx_inspect.py extras  <file.fbx>
    python3 tools/fbx_inspect.py mats    <file.fbx>
    python3 tools/fbx_inspect.py bonesize <file.fbx> "<nama tulang>" [...]
"""
import collections
import re
import struct
import sys
import zlib


class Node:
    __slots__ = ("name", "props", "children")

    def __init__(self, name, props, children):
        self.name = name
        self.props = props
        self.children = children


def _props(buf, off, count):
    props = []
    for _ in range(count):
        code = buf[off:off + 1]
        off += 1
        if code == b"Y":
            props.append(struct.unpack_from("<h", buf, off)[0]); off += 2
        elif code == b"C":
            props.append(bool(buf[off])); off += 1
        elif code == b"I":
            props.append(struct.unpack_from("<i", buf, off)[0]); off += 4
        elif code == b"F":
            props.append(struct.unpack_from("<f", buf, off)[0]); off += 4
        elif code == b"D":
            props.append(struct.unpack_from("<d", buf, off)[0]); off += 8
        elif code == b"L":
            props.append(struct.unpack_from("<q", buf, off)[0]); off += 8
        elif code in (b"f", b"d", b"l", b"i", b"b"):
            length, encoding, comp_len = struct.unpack_from("<III", buf, off)
            off += 12
            raw = buf[off:off + comp_len]
            off += comp_len
            if encoding == 1:
                raw = zlib.decompress(raw)
            fmt = {b"f": "f", b"d": "d", b"l": "q", b"i": "i", b"b": "b"}[code]
            size = struct.calcsize(fmt)
            props.append(list(struct.unpack("<%d%s" % (length, fmt), raw[:length * size])))
        elif code in (b"S", b"R"):
            length = struct.unpack_from("<I", buf, off)[0]
            off += 4
            raw = buf[off:off + length]
            off += length
            props.append(raw.decode("utf-8", "replace") if code == b"S" else raw)
        else:
            raise ValueError("kode properti tak dikenal: %r" % code)
    return props, off


def _nodes(buf, off, end):
    nodes = []
    while off < end:
        if buf[off:off + 13] == b"\x00" * 13:
            return nodes, off + 13
        end_offset, num_props, _prop_len = struct.unpack_from("<III", buf, off)
        off += 12
        if end_offset == 0:
            return nodes, off + 13
        name_len = buf[off]
        off += 1
        name = buf[off:off + name_len].decode("utf-8", "replace")
        off += name_len
        props, off = _props(buf, off, num_props)
        children = []
        if off < end_offset:
            children, off = _nodes(buf, off, end_offset)
        off = end_offset
        nodes.append(Node(name, props, children))
    return nodes, off


def load(path):
    buf = open(path, "rb").read()
    if buf[:21] != b"Kaydara FBX Binary  \x00":
        raise SystemExit("bukan FBX biner: " + path)
    nodes, _ = _nodes(buf, 27, len(buf))
    return Node("(root)", [], nodes)


def find(node, name):
    for child in node.children:
        if child.name == name:
            return child
    return None


def child_prop(node, name, default=None):
    child = find(node, name)
    return child.props[0] if child is not None and child.props else default


def objects(fbx):
    """(geometries, models, materials, deformers) berisi (id, nama, node)."""
    section = find(fbx, "Objects")
    buckets = {"Geometry": [], "Model": [], "Material": [], "Deformer": []}
    for node in section.children:
        if node.name not in buckets or not node.props:
            continue
        ident = node.props[0]
        name = ""
        for prop in node.props[1:]:
            if isinstance(prop, str):
                name = prop.split("\x00")[0]
                break
        buckets[node.name].append((ident, name, node))
    return (buckets["Geometry"], buckets["models" if False else "Model"],
            buckets["Material"], buckets["Deformer"])


def connections(fbx):
    links = []
    for node in find(fbx, "Connections").children:
        if node.name == "C" and len(node.props) >= 3:
            kind, child, parent = node.props[0], node.props[1], node.props[2]
            extra = node.props[3] if len(node.props) > 3 else None
            links.append((kind, child, parent, extra))
    return links


def polygons(node):
    """Kembalikan daftar poligon (indeks titik), dari PolygonVertexIndex."""
    raw = child_prop(node, "PolygonVertexIndex", [])
    polys, current = [], []
    for value in raw:
        if value < 0:
            current.append(~value)
            polys.append(current)
            current = []
        else:
            current.append(value)
    return polys


# ------------------------------------------------------------------ perintah --


def cmd_bones(fbx, path):
    models = objects(fbx)[1]
    print("%d tulang/model:" % len(models))
    for _ident, name, _node in models:
        print("   ", name)


def cmd_extras(fbx, path):
    """Tulang tambahan (kain/rambut/aksesori) yang bukan Bip001."""
    models = objects(fbx)[1]
    extras = [n for n, _ in collections.Counter(n for _, n, _ in models).items()
              if not n.startswith("Bip001") and not n.startswith("Avatar")]
    print("%d tulang tambahan:" % len(extras))
    for name in sorted(extras):
        print("   ", name)


def cmd_mats(fbx, path):
    """Material per geometri: urutan koneksi = urutan material index."""
    geoms, _models, mats, _ = objects(fbx)
    mat_by_id = {i: n for i, n, _ in mats}
    geom_by_id = {i: n for i, n, _ in geoms}
    used = collections.defaultdict(list)
    for kind, child, parent, _extra in connections(fbx):
        if child in mat_by_id and parent in geom_by_id:
            used[parent].append(mat_by_id[child])
    for ident, name, node in geoms:
        material_index = find(node, "LayerElementMaterial")
        mapping = child_prop(material_index, "MappingInformationType") if material_index else None
        polys = polygons(node)
        if not polys:
            continue
        if mapping != "ByPolygon" or material_index is None:
            print("%-14s %d poligon, satu material: %s" % (name, len(polys),
                                                          used.get(ident)))
            continue
        order = child_prop(material_index, "Materials", [])
        count = collections.Counter(order)
        print("%-14s %d poligon" % (name, len(polys)))
        for index, material in enumerate(used.get(ident, [])):
            print("      material[%d] = %-42s %d poligon" % (index, material,
                                                             count.get(index, 0)))


def _clusters(fbx):
    """Peta (id geometri, nama tulang) -> daftar (indeks titik, bobot).

    Struktur FBX: Geometry <- Skin Deformer <- Cluster. Nama tulang ada di nama
    cluster ("Bip001 HeadCluster" -> "Bip001 Head").
    """
    geoms, _models, _mats, deformers = objects(fbx)
    geometry_ids = {i for i, _, _ in geoms}
    kind_of = {i: (n.props[2] if len(n.props) > 2 and isinstance(n.props[2], str) else "")
               for i, _, n in deformers}
    links = connections(fbx)
    skin_of_geometry = {}
    for kind, child, parent, _extra in links:
        if kind_of.get(child) == "Skin" and parent in geometry_ids:
            skin_of_geometry[child] = parent
    clusters = collections.defaultdict(list)
    for ident, name, node in deformers:
        if kind_of.get(ident) != "Cluster":
            continue
        skin = None
        for kind, child, parent, _extra in links:
            if child == ident and parent in skin_of_geometry:
                skin = parent
        if skin is None:
            continue
        indexes = child_prop(node, "Indexes", [])
        weights = child_prop(node, "Weights", [])
        if not indexes:
            continue
        bone = name.split("\x00")[0]
        if bone.endswith("Cluster"):
            bone = bone[:-len("Cluster")]
        clusters[(skin_of_geometry[skin], bone)].append((indexes, weights))
    return clusters


def cmd_bonesize(fbx, path, wanted):
    """Ukuran geometri yang dibebankan ke tulang tertentu (radius & panjang)."""
    geoms, _models, _mats, _ = objects(fbx)
    vertices_by_id = {}
    for ident, name, node in geoms:
        raw = child_prop(node, "Vertices", [])
        vertices_by_id[ident] = [tuple(raw[i:i + 3]) for i in range(0, len(raw), 3)]
    clusters = _clusters(fbx)
    for want in wanted:
        total = 0
        for (geometry_id, bone), entries in clusters.items():
            if bone != want:
                continue
            points = vertices_by_id.get(geometry_id, [])
            for indexes, weights in entries:
                strong = [points[i] for i, w in zip(indexes, weights) if i < len(points) and w > 0.5]
                if not strong:
                    continue
                total += len(strong)
                xs = [p[0] for p in strong]
                ys = [p[1] for p in strong]
                zs = [p[2] for p in strong]
                print("%-26s %4d titik bobot>0.5  x %.3f..%.3f  y %.3f..%.3f  z %.3f..%.3f"
                      % (want, len(strong), min(xs), max(xs), min(ys), max(ys),
                         min(zs), max(zs)))
        if total == 0:
            print("%-26s (tidak ada titik dengan bobot > 0.5)" % want)


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 1
    command, path = argv[1], argv[2]
    fbx = load(path)
    if command == "bones":
        cmd_bones(fbx, path)
    elif command == "extras":
        cmd_extras(fbx, path)
    elif command == "mats":
        cmd_mats(fbx, path)
    elif command == "bonesize":
        cmd_bonesize(fbx, path, argv[3:])
    else:
        print(__doc__)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
