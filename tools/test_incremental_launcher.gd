extends SceneTree
## Cold launch using ONLY exported APK assets. Assemble the real modified gameplay pack.
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var store_script: GDScript = load("res://launcher/chunk_store.gd")
	var policy: GDScript = load("res://launcher/chunk_policy.gd")
	DirAccess.make_dir_recursive_absolute(store_script.ROOT)
	for entry in DirAccess.get_files_at(store_script.ROOT):
		DirAccess.remove_absolute(store_script.ROOT + entry)
	var target: Dictionary = store_script.read_index(args[0])
	var seed: Dictionary = store_script.read_index(store_script.SEED_INDEX)
	var store: RefCounted = store_script.new()
	store.add_source(store_script.SEED, seed)
	await store.plan(target, self)
	_check(store.download_bytes > 0 and store.download_bytes < 4 * 1024 * 1024,
		"APK seed reuse failed")
	for chunk in store.missing:
		var path: String = store_script.ROOT + "test.part"
		DirAccess.copy_absolute(args[1].path_join(chunk.sha256 + ".bin"), path)
		_check(store.accept_chunk(path, chunk), "Downloaded block rejected")
	_check(await store.assemble(target, self), "Real exported PCK assembly failed")
	_check(store_script.activate(target), "Real exported PCK activation failed")
	var scene: PackedScene = load("res://launcher/main.tscn")
	# Suppress network by pending marker, then explicitly exercise activation below.
	var marker := FileAccess.open("user://content_boot_pending", FileAccess.WRITE)
	marker.store_string("test")
	marker.close()
	var launcher := scene.instantiate()
	root.add_child(launcher)
	current_scene = launcher
	launcher.set("_active", target)
	launcher.call("_launch")
	for frame in range(15):
		await process_frame
	_check(current_scene is Node3D, "Updated game failed cold boot")
	if current_scene is Node3D:
		_check(is_equal_approx(float(current_scene.MOVE_SPEED), 5.01),
			"Stale bundled script loaded instead of updated pack")
	_check(not FileAccess.file_exists("user://content_boot_pending"), "Updated boot unconfirmed")
	_check(policy.verified(store_script.pack_path(target), target), "Activated pack damaged")
	for entry in DirAccess.get_files_at(store_script.ROOT):
		DirAccess.remove_absolute(store_script.ROOT + entry)
	print("[incremental-launcher] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
