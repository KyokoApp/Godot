extends RefCounted
## V2 manifest is data only; immutable chunk URLs derived here, never accepted from JSON.
const ENGINE := "4.5.2"
const MAX_BYTES := 256 * 1024 * 1024
const MAX_CHUNK := 1024 * 1024
const MAX_MANIFEST := 1024 * 1024
const PREFIX := "https://github.com/KyokoApp/Godot/releases/download/build-"


static func hex_string(value: Variant, minimum: int, maximum: int) -> bool:
	if not value is String or value.length() < minimum or value.length() > maximum:
		return false
	for character in value:
		if not character in "0123456789abcdef":
			return false
	return true


static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) \
		and value >= minimum and value <= maximum and value == int(value)


static func valid(data: Dictionary) -> bool:
	if data.get("schema") != 2 or data.get("engine") != ENGINE or data.get("min_launcher") != 2:
		return false
	if not hex_string(data.get("version"), 7, 40) or not hex_string(data.get("sha256"), 64, 64):
		return false
	if not integer(data.get("bytes"), 1, MAX_BYTES) or not data.get("chunks") is Array:
		return false
	if data.chunks.is_empty() or data.chunks.size() > 4096:
		return false
	var total := 0
	for chunk in data.chunks:
		if not chunk is Dictionary or not hex_string(chunk.get("sha256"), 64, 64) \
				or not integer(chunk.get("bytes"), 1, MAX_CHUNK):
			return false
		total += int(chunk.bytes)
	return total == int(data.bytes)


static func sha(buffer: PackedByteArray) -> String:
	var hash_context := HashingContext.new()
	hash_context.start(HashingContext.HASH_SHA256)
	hash_context.update(buffer)
	return hash_context.finish().hex_encode()


static func verified(path: String, manifest: Dictionary) -> bool:
	if not valid(manifest):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() != int(manifest.bytes):
		return false
	file.close()
	return FileAccess.get_sha256(path) == manifest.sha256


static func chunk_url(manifest: Dictionary, chunk: Dictionary) -> String:
	return PREFIX + str(manifest.version) + "/" + str(chunk.sha256) + ".bin"
