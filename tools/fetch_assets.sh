#!/usr/bin/env bash
# Ambil aset biner besar (2 pustaka animasi UAL + sampul padang).
#
# Kenapa tidak di git: UAL1 + UAL2 = ± 15,7 MB berkas biner. Semuanya tersimpan sebagai lampiran rilis GitHub (tag `assets-v1`)
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

MANNEQUIN="$ROOT/project/assets/mannequin"
COMBAT="$ROOT/project/assets/combat"

GLBS=("UAL1_Standard.glb" "UAL2_Standard.glb")

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

# Klon CI biasanya hanya punya commit terakhir (shallow). Kalau commit sumber
# belum ada di klon, ambil satu commit itu saja — jauh lebih murah daripada
# mengunduh seluruh riwayat.
ensure_commit() {
	if git -C "$ROOT" cat-file -e "$COMMIT^{commit}" 2>/dev/null; then
		return 0
	fi
	echo "  commit $COMMIT belum ada di klon, mengambil satu commit..."
	git -C "$ROOT" fetch --depth=1 origin "$COMMIT" >/dev/null 2>&1 || return 1
	git -C "$ROOT" cat-file -e "$COMMIT^{commit}" 2>/dev/null
}

git_file() { # git_file <path-di-repo> <tujuan>
	local src="$1" dest="$2"
	if ok "$dest"; then
		return 0
	fi
	if ! ensure_commit; then
		return 1
	fi
	if ! git -C "$ROOT" cat-file -e "$COMMIT:$src" 2>/dev/null; then
		return 1
	fi
	mkdir -p "$(dirname "$dest")"
	git -C "$ROOT" show "$COMMIT:$src" >"$dest"
	note "git $src"
	return 0
}

# Kedua pengumpul mengembalikan 0 HANYA kalau semua berkas siap. Kalau ada satu
# saja yang gagal, seluruh langkah dianggap gagal — campuran berkas dari dua
# sumber dengan versi berbeda lebih berbahaya daripada gagal terang-terangan.
collect_release() {
	local failed=0
	for glb in "${GLBS[@]}"; do
		case "$glb" in
			UAL1_Standard.glb) fetch "$glb" "$MANNEQUIN/$glb" || failed=1 ;;
			*) fetch "$glb" "$COMBAT/$glb" || failed=1 ;;
		esac
	done
	return $failed
}

collect_git() {
	local failed=0
	git_file "project/assets/mannequin/UAL1_Standard.glb" "$MANNEQUIN/UAL1_Standard.glb" || failed=1
	git_file "project/assets/combat/UAL2_Standard.glb" "$COMBAT/UAL2_Standard.glb" || failed=1
	return $failed
}

echo "aset A-Sekai (mode: $MODE)"
if [ "$MODE" = "release" ]; then
	echo "sumber: $ASSET_BASE"
	if ! collect_release; then
		# Rilis belum siap (mis. workflow aset belum pernah jalan) -> pakai
		# riwayat git sebagai cadangan supaya build tidak pernah mentok.
		echo "  rilis belum lengkap, beralih ke riwayat git ($COMMIT)"
		collect_git || true
	fi
else
	echo "sumber: git $COMMIT"
	collect_git || true
fi

# Verifikasi akhir: semua berkas harus ada dan tidak kosong (unduhan gagal yang
# tersimpan sebagai halaman HTML tidak lolos).
missing=0
check_file() {
	local path="$1" min="$2"
	if [ ! -f "$path" ] || [ "$(stat -c%s "$path")" -lt "$min" ]; then
		echo "  KURANG: $path" >&2
		missing=1
	fi
}
check_file "$MANNEQUIN/UAL1_Standard.glb" 1000000
check_file "$COMBAT/UAL2_Standard.glb" 1000000

if [ "$missing" != 0 ]; then
	echo "GAGAL: ada aset yang tidak bisa diambil" >&2
	exit 1
fi

echo "aset siap:"
printf '  %-46s %8s\n' "project/assets/mannequin/UAL1_Standard.glb" "$(stat -c%s "$MANNEQUIN/UAL1_Standard.glb")"
printf '  %-46s %8s\n' "project/assets/combat/UAL2_Standard.glb" "$(stat -c%s "$COMBAT/UAL2_Standard.glb")"
