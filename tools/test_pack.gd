extends SceneTree
## Pack dibuka dalam proses baru, sebelum resource gameplay masuk cache.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not ProjectSettings.load_resource_pack(args[0], true):
		push_error("Pack gagal dipasang")
		quit(1)
		return
	var scene: PackedScene = load("res://src/game/main.tscn")
	if scene == null or not scene.can_instantiate():
		quit(1)
		return
	var marker := FileAccess.open("user://content_boot_pending", FileAccess.WRITE)
	marker.store_string("test")
	marker.close()
	root.add_child(scene.instantiate())
	for frame in range(5):
		await process_frame
	if FileAccess.file_exists("user://content_boot_pending"):
		push_error("Konten tidak mengonfirmasi boot")
		quit(1)
		return
	print("[pack-test] HASIL: OK")
	quit(0)
