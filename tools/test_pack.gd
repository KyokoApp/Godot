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
	if not FileAccess.file_exists("res://licenses/GDQuest-MIT.txt"):
		push_error("Lisensi shader partikel tidak ikut content pack")
		quit(1)
		return
	for path in ["fire_shoot", "fire_explode", "fire_loop", "pet_crackle", "step_grass_0",
			"step_dirt_0", "step_stone_0"]:
		var sound: AudioStream = load("res://assets/audio/" + path + ".wav")
		if sound == null or sound.get_length() <= 0:
			push_error("Audio tidak ikut PCK: " + path)
			quit(1)
			return
	var nature_scene: PackedScene = load("res://assets/nature/RockPath_Round_Wide.gltf")
	if nature_scene == null or not nature_scene.can_instantiate():
		push_error("Aset nature tidak masuk PCK")
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
