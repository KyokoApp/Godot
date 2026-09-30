extends SceneTree
## Offline transaction tests using short blocks; never touches the real APK seed.
const Store = preload("res://launcher/chunk_store.gd")
const Policy = preload("res://launcher/chunk_policy.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _write(path: String, data: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(data)
	file.close()


func _manifest(blocks: Array[String]) -> Dictionary:
	var chunks: Array[Dictionary] = []
	var whole := ""
	for block in blocks:
		chunks.append({"bytes": block.length(), "sha256": Policy.sha(block.to_utf8_buffer())})
		whole += block
	return {"schema": 2, "engine": "4.5.2", "min_launcher": 2, "version": "abcdef1",
		"bytes": whole.length(), "sha256": Policy.sha(whole.to_utf8_buffer()), "chunks": chunks}


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(Store.ROOT)
	var old := _manifest(["asset unchanged", "old script"])
	var next := _manifest(["asset unchanged", "new script", "new script"])
	_check(Policy.valid(next), "Valid manifest rejected")
	for key in ["version", "sha256", "bytes", "chunks", "min_launcher"]:
		var bad := next.duplicate(true)
		bad[key] = "../escape"
		_check(not Policy.valid(bad), "Invalid field accepted: " + key)
	var fractional := next.duplicate(true)
	fractional.chunks[0].bytes = 1.5
	_check(not Policy.valid(fractional), "Fractional bytes accepted")
	_write(Store.pack_path(old), "asset unchangedold script")
	_check(Store.activate(old), "Initial activation failed")
	var store := Store.new()
	store.add_source(Store.pack_path(old), old)
	await store.plan(next, self)
	_check(store.missing.size() == 1 and store.download_bytes == 10,
		"Unchanged asset/repeated blocks downloaded again")
	_check(Store.read_index(Store.ACTIVE).sha256 == old.sha256, "Plan altered active index")
	var temp := Store.ROOT + "test.part"
	_write(temp, "wrong body")
	_check(not store.accept_chunk(temp, next.chunks[1]), "Bad checksum accepted")
	_check(not await store.assemble(next, self), "Missing block accepted")
	_check(Store.read_index(Store.ACTIVE).sha256 == old.sha256, "Failed update lost old pack")
	_write(temp, "new script")
	_check(store.accept_chunk(temp, next.chunks[1]), "Valid block rejected")
	# New store = app restarted after download, before assembly.
	var retry := Store.new()
	retry.add_source(Store.pack_path(old), old)
	await retry.plan(next, self)
	_check(retry.download_bytes == 0, "Completed cache not reused after restart")
	_check(await retry.assemble(next, self), "Reconstruction failed")
	_check(Policy.verified(Store.pack_path(next), next), "Whole-pack hash mismatch")
	_check(Store.activate(next), "Activation failed")
	_check(Store.read_index(Store.PREVIOUS).sha256 == old.sha256, "Rollback pack lost")
	Store.rollback()
	_check(Store.read_index(Store.ACTIVE).sha256 == old.sha256, "Boot rollback failed")
	# Corrupt source is re-downloaded, not blindly trusted by index hash.
	_write(Store.pack_path(old), "asset corruptedold script")
	var corrupt := Store.new()
	corrupt.add_source(Store.pack_path(old), old)
	await corrupt.plan(next, self)
	_check(corrupt.download_bytes >= 15, "Corrupt source trusted")
	for entry in DirAccess.get_files_at(Store.ROOT):
		DirAccess.remove_absolute(Store.ROOT + entry)
	print("[chunks-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
