#!/usr/bin/env bash
# Ambil pratinjau avatar dari komentar commit CI (satu-satunya jalur yang
# bekerja: unduhan artefak sering gagal EOF, komentar commit tidak).
#
#   tools/fetch_previews.sh [commit] [folder]
#
# Tanpa argumen: commit terakhir di branch yang sedang aktif, folder ./preview.
set -euo pipefail
commit="${1:-$(git rev-parse HEAD)}"
out="${2:-preview}"
mkdir -p "$out"
gh api "repos/KyokoApp/Godot/commits/$commit/comments" --jq '.[].body' > "$out/comments.txt"
python3 - "$out" <<'PY'
import base64, os, re, sys
out = sys.argv[1]
text = open(os.path.join(out, "comments.txt"), encoding="utf-8").read()
# Tiap gambar dikirim sebagai satu komentar: "### pratinjau: <nama>" + blok base64.
sections = re.split(r"^### pratinjau: ", text, flags=re.M)
print("komentar pratinjau: %d" % (len(sections) - 1))
for section in sections[1:]:
    name = section.split("\n", 1)[0].strip() or "preview.jpg"
    found = re.search(r"[A-Za-z0-9+/]{500,}={0,2}", section)
    if found is None:
        print("%-34s TANPA DATA" % name)
        continue
    path = os.path.join(out, name)
    with open(path, "wb") as handle:
        handle.write(base64.b64decode(found.group(0)))
    print("%-34s %8d B" % (name, os.path.getsize(path)))
PY
