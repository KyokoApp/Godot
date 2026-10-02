#!/usr/bin/env python3
"""Cek lokal untuk bug kelas 'layar biru' — tangkap sebelum sampai ke HP.

Kenapa file ini ada
-------------------
Pada project sebelumnya, satu baris seperti ini:

    var lbl := ["VERSI", "MODE", "GRAFIK", "STATUS"][k2]

mematikan seluruh aplikasi tanpa satu pesan pun di HP. Indeks ke Array
literal menghasilkan Variant, dan `:=` dari Variant adalah COMPILE ERROR
di Godot 4.5 — bukan error runtime, jadi tidak muncul di log saat main.
Skrip yang di-preload skrip utama ikut mati, dan yang tersisa hanya warna
latar boot: layar biru polos tanpa loading screen.

Kenapa alat otomatis tidak menangkapnya waktu itu:
  - gdparse hanya memeriksa SINTAKS, bukan inferensi tipe milik engine
  - gdlint memeriksa konvensi, bukan tipe
  - probe lama hanya memuat skrip di dalam satu folder; skrip di luar
    folder itu tidak pernah dikompilasi sama sekali

Selain itu alat ini juga menangkap dua hal yang pernah menjatuhkan build:
  - deklarasi ganda di satu berkas (mis. `static func clip_count()` dua kali)
    -> engine menolak seluruh berkas dan semua skrip yang bergantung padanya
  - `var x := fungsi_tanpa_tipe()` di skrip sendiri -> "Cannot infer the type"

Jadi alat ini menutup celah yang tersisa: jalan lokal tanpa Godot,
sebelum commit. Exit code 0 = bersih, 1 = ada temuan.

Dipakai CI juga — jadi tidak mungkin build terbit tanpa lolos ini.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GODOT_DIR = ROOT  # seluruh repo, bukan cuma project/

# Array yang dideklarasikan TANPA generics -> elemennya Variant.
# re.M wajib (tanpa itu jangkar ^ hanya cocok baris pertama) dan
# [ \t]* wajib (baris GDScript ter-indentasi).
TYPED_ARRAY_RE = re.compile(
    r"^[ \t]*(?:@onready[ \t]+|static[ \t]+)?var[ \t]+([A-Za-z_]\w*)"
    r"[ \t]*:[ \t]*Array[ \t]*=",
    re.M,
)
# `var x := <expr>` — '=' tunggal BUKAN ':=', jadi tidak ikut tertangkap.
INFER_RE = re.compile(r"^([ \t]*)var[ \t]+([A-Za-z_]\w*)[ \t]*:=[ \t]+(.+?)[ \t]*$", re.M)
# Indeks ke literal Array di ujung ekspresi: [ ... ][expr]
LITERAL_INDEX_RE = re.compile(r"\[[^\[\]]*\][ \t]*\[[^\]]*\][ \t]*$")
# float(arr[i]["x"]) aman karena cast-nya menentukan tipe.
SAFE_WRAP_RE = re.compile(
    r"\b(?:float|int|String|str|Color|Vector[23]|bool)"
    r"[ \t]*\([ \t]*[A-Za-z_]\w*[ \t]*\["
)
# Deklarasi tingkat atas; `static func` dihitung sama seperti `func`.
# Hanya deklarasi tingkat atas (kolom 0); variabel lokal di dalam fungsi
# boleh memakai nama yang sama dengan variabel fungsi lain.
DECL_RE = re.compile(
    r"^(?:static[ \t]+)?(?:func|var|const|signal|enum)[ \t]+([A-Za-z_]\w*)",
    re.M,
)
FUNC_RE = re.compile(
    r"^[ \t]*(?:static[ \t]+)?func[ \t]+([A-Za-z_]\w*)[ \t]*\(([^)]*)\)"
    r"[ \t]*(?:->[ \t]*([A-Za-z_][\w\[\]\.]*))?",
    re.M,
)
PRELOAD_RE = re.compile(
    r'^[ \t]*const[ \t]+([A-Za-z_]\w*)[ \t]*=[ \t]*preload\("res://([^"]+)"\)',
    re.M,
)
CALL_EXPR_RE = re.compile(r"^(?:([A-Za-z_]\w*)\.)?([A-Za-z_]\w*)[ \t]*\(")


def untyped_returns(src: str, preloads: dict[str, str], cache: dict[str, dict[str, str]]) -> list[str]:
    """Nama fungsi milik skrip sendiri yang tidak punya tipe balikan eksplisit."""
    problems: list[str] = []
    for lineno, line in enumerate(src.split("\n"), 1):
        m = INFER_RE.match(line)
        if not m:
            continue
        name, expr = m.group(2), m.group(3)
        call = CALL_EXPR_RE.match(expr.strip())
        if not call:
            continue
        owner, func_name = call.group(1), call.group(2)
        target: dict[str, str] | None = None
        if owner is None:
            target = {m.group(1): m.group(3) for m in FUNC_RE.finditer(src)}
        elif owner in preloads:
            path = ROOT / "project" / preloads[owner].removeprefix("res://")
            if path.name in cache:
                target = cache[path.name]
            elif path.is_file():
                target = {m.group(1): m.group(3)
                          for m in FUNC_RE.finditer(path.read_text(encoding="utf-8"))}
                cache[path.name] = target
        if not target or func_name not in target:
            continue
        if not target[func_name]:
            where = f"{owner}.{func_name}" if owner else func_name
            problems.append(
                f"{name}: `var {name} := {where}(...)` PASTI gagal compile — "
                f"fungsi {where} tidak punya tipe balikan eksplisit, jadi `:=` "
                f"tidak bisa menyimpulkan tipe. Tulis tipe eksplisit."
            )
    return problems


def gd_files() -> list[Path]:
    out: list[Path] = []
    for dirpath, dirnames, filenames in os.walk(GODOT_DIR):
        dirnames[:] = [d for d in dirnames if not d.startswith(".") and d not in ("build", "keystore")]
        for name in filenames:
            if name.endswith(".gd"):
                out.append(Path(dirpath) / name)
    return sorted(out)


def main() -> int:
    files = gd_files()
    problems: list[str] = []
    warnings: list[str] = []

    cache: dict[str, dict[str, str]] = {}
    for path in files:
        rel = path.relative_to(ROOT)
        src = path.read_text(encoding="utf-8")
        plain_arrays = {m.group(1) for m in TYPED_ARRAY_RE.finditer(src)}

        # (3) Deklarasi ganda: engine menolak seluruh berkas, bukan cuma baris itu.
        seen: dict[str, int] = {}
        for lineno, line in enumerate(src.split("\n"), 1):
            m = DECL_RE.match(line)
            if not m:
                continue
            name = m.group(1)
            if name in seen:
                problems.append(
                    f"{rel}:{lineno}: deklarasi `{name}` dobel (sudah ada di baris "
                    f"{seen[name]}) — Godot menolak seluruh berkas dan semua skrip "
                    f"yang meng-preload-nya. Hapus salah satu."
                )
            else:
                seen[name] = lineno

        for lineno, line in enumerate(src.split("\n"), 1):
            m = INFER_RE.match(line)
            if not m:
                continue
            name, expr = m.group(2), m.group(3)

            # (1) PASTI gagal: indeks ke Array literal.
            if LITERAL_INDEX_RE.search(expr):
                problems.append(
                    f"{rel}:{lineno}: `var {name} := [ ... ][idx]` PASTI gagal "
                    f"compile — indeks ke Array literal menghasilkan Variant, "
                    f"dan `:=` dari Variant ditolak Godot. Tulis tipe "
                    f"eksplisit: `var {name}: String = [ ... ][idx]`"
                )
                continue

            # (2) Kemungkinan gagal: indeks ke Array tanpa generics.
            if SAFE_WRAP_RE.search(expr):
                continue  # dibungkus cast -> tipe pasti, aman
            if any(f"{arr}[" in expr for arr in plain_arrays):
                warnings.append(
                    f"{rel}:{lineno}: `var {name} := ...` bisa gagal compile — "
                    f"ekspresi mengindeks Array tanpa generics (hasilnya "
                    f"Variant). Kalau CI bilang 'Cannot infer the type of "
                    f"{name}', tulis tipe eksplisit."
                )

        # (4) `var x := fungsi_tanpa_tipe()` di skrip sendiri.
        preloads = {m.group(1): m.group(2) for m in PRELOAD_RE.finditer(src)}
        for problem in untyped_returns(src, preloads, cache):
            problems.append(f"{rel}:{problem}")

    print(f"Diperiksa: {len(files)} file .gd")
    for w in warnings:
        print("WASPADA:", w)
    for p in problems:
        print("EROR:", p)
    if problems:
        print("GAGAL — perbaiki dulu sebelum commit.")
        return 1
    print("BERSIH")
    return 0


if __name__ == "__main__":
    sys.exit(main())
