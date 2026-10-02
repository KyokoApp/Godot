#!/usr/bin/env bash
# Ambil aset biner besar (FBX avatar + 15 tekstur + 2 pustaka animasi UAL).
#
# Kenapa tidak di git: FBX 4,9 MB + tekstur 3,7 MB + UAL 15,7 MB = ± 24 MB
# berkas biner. Semuanya tersimpan sebagai lampiran rilis GitHub (tag `assets-v1`)
# dan diunduh saat dibutuhkan, jadi klon repo tetap ringan dan tidak ada berkas
# besar yang ikut berubah di riwayat.
#
# Cara pakai:
#   tools/fetch_assets.sh              # unduh dari rilis (butuh internet)
#   tools/fetch_assets.sh --from-git   # ambil dari riwayat git lokal (tanpa internet)
#   tools/fetch_assets.sh --from-git <commit>
#   FORCE=1 tools/fetch_assets.sh      # unduh ulang walau berkas sudah ada
#
# Semua berkas dicek ukurannya (> 1 KB) supaya unduhan yang gagal (halaman HTML
# "404" tersimpan sebagai .fbx) tidak lolos diam-diam.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSET_TAG="${ASEKAI_ASSET_TAG:-assets-v1}"
ASSET_REPO="${ASEKAI_ASSET_REPO:-KyokoApp/Godot}"
ASSET_BASE="${ASEKAI_ASSET_BASE:-https://github.com/${ASSET_REPO}/releases/download/${ASSET_TAG}}"
DEFAULT_COMMIT="0d56df0d77cde7de8df8f31194815e90fee294aa"

AURELIA="$ROOT/project/assets/aurelia"
TEXTURES="$AURELIA/Textures"
MANNEQUIN="$ROOT/project/assets/mannequin"
COMBAT="$ROOT/project/assets/combat"

FBX="Avatar_Boy_Pole_Lohen.fbx"
GLBS=("UAL1_Standard.glb" "UAL2_Standard.glb")
TEXTURE_FILES=(
	Avatar_Boy01_Tex_FaceLightmap.png
	Avatar_Boy_Pole_Lohen_Tex_Body_Diffuse.png
	Avatar_Boy_Pole_Lohen_Tex_Body_Lightmap.png
	Avatar_Boy_Pole_Lohen_Tex_Body_Normalmap.png
	Avatar_Boy_Pole_Lohen_Tex_Body_Shadow_Ramp.png
	Avatar_Boy_Pole_Lohen_Tex_Face_Diffuse.png
	Avatar_Boy_Pole_Lohen_Tex_Hair_Diffuse.png
	Avatar_Boy_Pole_Lohen_Tex_Hair_Lightmap.png
	Avatar_Boy_Pole_Lohen_Tex_Hair_Normalmap.png
	Avatar_Boy_Pole_Lohen_Tex_Hair_Shadow_Ramp.png
	Avatar_Tex_Appear_Face_Mask.png
	Avatar_Tex_Appear_Pupil_Mask.png
	Avatar_Tex_Face01_Shadow.png
	Avatar_Tex_MetalMap.png
	Avatar_Tex_Specular_Ramp.png
)

MODE="release"
COMMIT="$DEFAULT_COMMIT"
if [ "${1:-}" = "--from-git" ]; then
	MODE="git"
	COMMIT="${2:-$DEFAULT_COMMIT}"
fi

ok() { # ok <berkas> -> 0 kalau sudah ada dan cukup besar
	[ -f "$1" ] || return 1
	if [ "${FORCE:-0}" = "1" ]; then
		return 1
	fi
	[ "$(stat -c%s "$1")" -gt 1024 ]
}

note() { printf '  %s\n' "$*"; }

fetch() { # fetch <nama-di-rilis> <tujuan>
	local name="$1" dest="$2"
	if ok "$dest"; then
		return 0
	fi
	mkdir -p "$(dirname "$dest")"
	local url="$ASSET_BASE/$name"
	local tmp="$dest.part"
	if ! curl -fsSL --retry 3 --retry-delay 2 -o "$tmp" "$url"; then
		rm -f "$tmp"
		return 1
	fi
	if [ "$(stat -c%s "$tmp")" -le 1024 ]; then
		rm -f "$tmp"
		return 1
	fi
	mv "$tmp" "$dest"
	note "unduh $name"
	return 0
}

git_file() { # git_file <path-di-repo> <tujuan>
	local src="$1" dest="$2"
	if ok "$dest"; then
		return 0
	fi
	if ! git -C "$ROOT" cat-file -e "$COMMIT:$src" 2>/dev/null; then
		return 1
	fi
	mkdir -p "$(dirname "$dest")"
	git -C "$ROOT" show "$COMMIT:$src" >"$dest"
	note "git $src"
	return 0
}

missing=0

collect_release() {
	fetch "$FBX" "$AURELIA/$FBX" || missing=1
	for glb in "${GLBS[@]}"; do
		case "$glb" in
			UAL1_Standard.glb) fetch "$glb" "$MANNEQUIN/$glb" || missing=1 ;;
			*) fetch "$glb" "$COMBAT/$glb" || missing=1 ;;
		esac
	done
	for tex in "${TEXTURE_FILES[@]}"; do
		fetch "$tex" "$TEXTURES/$tex" || missing=1
	done
}

collect_git() {
	git_file "aurelia-debug/$FBX" "$AURELIA/$FBX" || missing=1
	git_file "project/assets/mannequin/UAL1_Standard.glb" "$MANNEQUIN/UAL1_Standard.glb" || missing=1
	git_file "project/assets/combat/UAL2_Standard.glb" "$COMBAT/UAL2_Standard.glb" || missing=1
	for tex in "${TEXTURE_FILES[@]}"; do
		git_file "aurelia-debug/Textures/$tex" "$TEXTURES/$tex" || missing=1
	done
}

echo "aset A-Sekai (mode: $MODE)"
if [ "$MODE" = "release" ]; then
	echo "sumber: $ASSET_BASE"
	if ! collect_release; then
		# Rilis belum siap (mis. workflow aset belum pernah jalan) -> pakai
		# riwayat git sebagai cadangan supaya build tidak pernah mentok.
		echo "  rilis tidak lengkap, beralih ke riwayat git ($COMMIT)"
		missing=0
		collect_git
	fi
else
	echo "sumber: git $COMMIT"
	collect_git
fi

if [ "$missing" != 0 ]; then
	echo "GAGAL: ada aset yang tidak bisa diambil" >&2
	exit 1
fi

echo "aset siap:"
printf '  %-46s %8s\n' "project/assets/aurelia/$FBX" "$(stat -c%s "$AURELIA/$FBX")"
printf '  %-46s %8s\n' "project/assets/aurelia/Textures ($(ls -1 "$TEXTURES" | wc -l) berkas)" "$(du -sh "$TEXTURES" | cut -f1)"
printf '  %-46s %8s\n' "project/assets/mannequin/UAL1_Standard.glb" "$(stat -c%s "$MANNEQUIN/UAL1_Standard.glb")"
printf '  %-46s %8s\n' "project/assets/combat/UAL2_Standard.glb" "$(stat -c%s "$COMBAT/UAL2_Standard.glb")"
