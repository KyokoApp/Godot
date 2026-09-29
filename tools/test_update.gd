extends SceneTree

const Policy = preload("res://launcher/update_policy.gd")
var _failures := 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _init() -> void:
	var path := "user://test-update.part"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("test content")
	file.close()
	var manifest := {
		"schema": 1, "engine": "4.5.2", "min_launcher": 1,
		"version": "test", "bytes": 12,
		"sha256": FileAccess.get_sha256(path),
		"url": Policy.RELEASE_PREFIX + "test/content.pck",
	}
	_check(Policy.valid_manifest(manifest), "Manifest valid ditolak")
	_check(Policy.verified(path, manifest), "Checksum valid ditolak")
	var invalid := manifest.duplicate()
	invalid["min_launcher"] = 2
	_check(not Policy.valid_manifest(invalid), "Launcher incompatible diterima")
	invalid = manifest.duplicate()
	invalid["engine"] = "4.6"
	_check(not Policy.valid_manifest(invalid), "Engine incompatible diterima")
	invalid = manifest.duplicate()
	invalid["url"] = "https://example.com/content.pck"
	_check(not Policy.valid_manifest(invalid), "Host asing diterima")
	invalid = manifest.duplicate()
	invalid["bytes"] = Policy.MAX_PACK_BYTES + 1
	_check(not Policy.valid_manifest(invalid), "Pack terlalu besar diterima")
	_check(not Policy.valid_manifest({}), "Manifest kosong diterima")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("bad! content")
	file.close()
	_check(not Policy.verified(path, manifest), "File rusak diterima")
	DirAccess.remove_absolute(path)
	_check(not Policy.verified(path, manifest), "File hilang diterima")
	print("[update-test] gagal: ", _failures)
	quit(0 if _failures == 0 else 1)
