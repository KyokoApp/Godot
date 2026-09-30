extends RefCounted
## Bounded buffers; stage to a new pack and activate only after its whole SHA matches.
const Policy = preload("res://launcher/chunk_policy.gd")
const SEED := "res://bootstrap/base.pck"
const SEED_INDEX := "res://bootstrap/base.json"
const ROOT := "user://updates-v2/"
const ACTIVE := ROOT + "active.json"
const PREVIOUS := ROOT + "previous.json"

var sources: Dictionary = {}
var missing: Array[Dictionary] = []
var download_bytes := 0


static func read_index(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > Policy.MAX_MANIFEST:
		return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	return data if data is Dictionary and Policy.valid(data) else {}


static func pack_path(manifest: Dictionary) -> String:
	return ROOT + str(manifest.get("sha256", "invalid")) + ".pck"


static func cache_path(sha: String) -> String:
	return ROOT + sha + ".bin"


static func save_index(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	return ok and DirAccess.rename_absolute(path + ".tmp", path) == OK


func add_source(path: String, manifest: Dictionary) -> void:
	if not Policy.valid(manifest) or not FileAccess.file_exists(path):
		return
	var offset := 0
	for chunk in manifest.chunks:
		var candidates: Array = sources.get(chunk.sha256, [])
		candidates.append({"path": path, "offset": offset, "bytes": int(chunk.bytes)})
		sources[chunk.sha256] = candidates
		offset += int(chunk.bytes)


static func read_block(source: Dictionary) -> PackedByteArray:
	var file := FileAccess.open(source.path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	file.seek(int(source.offset))
	return file.get_buffer(int(source.bytes))


func plan(manifest: Dictionary, tree: SceneTree) -> void:
	missing.clear()
	download_bytes = 0
	var seen: Dictionary = {}
	for chunk in manifest.chunks:
		if seen.has(chunk.sha256):
			continue
		seen[chunk.sha256] = true
		var candidates: Array = sources.get(chunk.sha256, [])
		candidates.push_front({"path": cache_path(chunk.sha256), "offset": 0, "bytes": chunk.bytes})
		var found: Dictionary = {}
		for candidate in candidates:
			if not FileAccess.file_exists(candidate.path):
				continue
			var data := read_block(candidate)
			if data.size() == int(chunk.bytes) and Policy.sha(data) == chunk.sha256:
				found = candidate
				break
		if found.is_empty():
			missing.append(chunk)
			download_bytes += int(chunk.bytes)
			sources.erase(chunk.sha256)
		else:
			sources[chunk.sha256] = [found]
		await tree.process_frame


func accept_chunk(path: String, chunk: Dictionary) -> bool:
	var source := {"path": path, "offset": 0, "bytes": int(chunk.bytes)}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() != int(chunk.bytes):
		return false
	file.close()
	if Policy.sha(read_block(source)) != chunk.sha256:
		return false
	var destination := cache_path(chunk.sha256)
	if DirAccess.rename_absolute(path, destination) != OK:
		return false
	source.path = destination
	sources[chunk.sha256] = [source]
	return true


func assemble(manifest: Dictionary, tree: SceneTree) -> bool:
	var path := pack_path(manifest)
	var file := FileAccess.open(path + ".part", FileAccess.WRITE)
	if file == null:
		return false
	var ok := true
	for chunk in manifest.chunks:
		var candidates: Array = sources.get(chunk.sha256, [])
		if candidates.is_empty():
			ok = false
			break
		var data: PackedByteArray = read_block(candidates[0])
		if data.size() != int(chunk.bytes) or Policy.sha(data) != chunk.sha256:
			ok = false
			break
		file.store_buffer(data)
		if file.get_error() != OK:
			ok = false
			break
		await tree.process_frame
	file.close()
	if not ok or not Policy.verified(path + ".part", manifest):
		DirAccess.remove_absolute(path + ".part")
		return false
	return DirAccess.rename_absolute(path + ".part", path) == OK


static func activate(manifest: Dictionary) -> bool:
	if not Policy.verified(pack_path(manifest), manifest):
		return false
	var old := read_index(ACTIVE)
	if not old.is_empty() and not save_index(PREVIOUS, old):
		return false
	return save_index(ACTIVE, manifest)


static func rollback() -> void:
	var old := read_index(PREVIOUS)
	if not old.is_empty() and Policy.verified(pack_path(old), old):
		save_index(ACTIVE, old)
	else:
		DirAccess.remove_absolute(ACTIVE)
	DirAccess.remove_absolute(PREVIOUS)


static func cleanup() -> void:
	# Call only on a cold start with no pending boot; never delete the bundled seed.
	var keep := [pack_path(read_index(ACTIVE)).get_file(),
		pack_path(read_index(PREVIOUS)).get_file(), "active.json", "previous.json"]
	for entry in DirAccess.get_files_at(ROOT):
		if not entry in keep and (entry.ends_with(".pck") or entry.ends_with(".tmp") \
				or entry.ends_with(".part")):
			DirAccess.remove_absolute(ROOT + entry)
	# Download cache is retained across interruptions, but bounded to one pack's size.
	var used := 0
	for entry in DirAccess.get_files_at(ROOT):
		if entry.ends_with(".bin"):
			var file := FileAccess.open(ROOT + entry, FileAccess.READ)
			if file != null:
				used += file.get_length()
				file.close()
			if used > Policy.MAX_BYTES:
				DirAccess.remove_absolute(ROOT + entry)
