extends RefCounted
## Hanya konten dari release repo ini, dengan kontrak launcher/engine yang cocok.

const LAUNCHER_VERSION := 1
const ENGINE_VERSION := "4.5.2"
const MAX_PACK_BYTES := 256 * 1024 * 1024
const RELEASE_PREFIX := "https://github.com/KyokoApp/Godot/releases/download/build-"


static func valid_manifest(data: Dictionary) -> bool:
	if data.get("schema") != 1 or data.get("engine") != ENGINE_VERSION:
		return false
	if not data.get("min_launcher") is float and not data.get("min_launcher") is int:
		return false
	if data["min_launcher"] < 1 or data["min_launcher"] > LAUNCHER_VERSION:
		return false
	if not data.get("bytes") is float and not data.get("bytes") is int:
		return false
	for field in ["version", "sha256", "url"]:
		if not data.get(field) is String:
			return false
	var version: String = str(data.get("version", ""))
	var sha: String = str(data.get("sha256", ""))
	var url: String = str(data.get("url", ""))
	var bytes: int = int(data.get("bytes", 0))
	if version.is_empty() or bytes <= 0 or bytes > MAX_PACK_BYTES:
		return false
	if sha.length() != 64:
		return false
	for character in sha:
		if not character in "0123456789abcdef":
			return false
	return url.begins_with(RELEASE_PREFIX) and url.ends_with("/content.pck")


static func verified(path: String, manifest: Dictionary) -> bool:
	if not valid_manifest(manifest) or not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() != int(manifest["bytes"]):
		return false
	file.close()
	return FileAccess.get_sha256(path) == manifest["sha256"]
