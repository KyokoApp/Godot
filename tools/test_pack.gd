extends SceneTree
## Pack dibuka dalam proses baru, sebelum resource gameplay masuk cache.

const CHARACTER_CLIPS := 85


func _init() -> void:
	call_deferred("_run")


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not ProjectSettings.load_resource_pack(args[0], true):
		_fail("Pack gagal dipasang")
		return
	if not _licenses_present():
		quit(1)
		return
	var problem := _verify_payload()
	if problem != "":
		_fail(problem)
		return
	await _boot_scene()


func _verify_payload() -> String:
	for path in ["fire_shoot", "fire_explode", "fire_loop", "pet_crackle", "step_grass_0",
			"step_dirt_0", "step_stone_0"]:
		var sound: AudioStream = load("res://assets/audio/" + path + ".wav")
		if sound == null or sound.get_length() <= 0:
			return "Audio tidak ikut PCK: " + path
	var card: Texture2D = load("res://assets/nature/grass_cards.png")
	if card == null or card.get_width() <= 0:
		return "Tekstur rumput tidak masuk PCK"
	# Dua berkas animasi wajib ikut: UAL1 (badan) dan UAL2 (pustaka combat).
	for model_path in ["res://assets/mannequin/UAL1_Standard.glb",
			"res://assets/combat/UAL2_Standard.glb"]:
		var model: PackedScene = load(model_path)
		if model == null or not model.can_instantiate():
			return "Model animasi tidak ikut PCK: " + model_path
	return ""


func _boot_scene() -> void:
	var scene: PackedScene = load("res://src/game/main.tscn")
	if scene == null or not scene.can_instantiate():
		_fail("Scene utama tidak bisa dibuka")
		return
	var marker := FileAccess.open("user://content_boot_pending", FileAccess.WRITE)
	marker.store_string("test")
	marker.close()
	var game: Node = scene.instantiate()
	root.add_child(game)
	for frame in range(5):
		await process_frame
	if FileAccess.file_exists("user://content_boot_pending"):
		_fail("Konten tidak mengonfirmasi boot")
		return
	var visual: Node = game.get("_visual")
	if visual == null or game.get("_player") == null:
		_fail("Pack tidak membangun mannequin/pemain")
		return
	var animation := visual.get("animation") as AnimationPlayer
	if animation == null or animation.get_animation_list().size() < CHARACTER_CLIPS:
		_fail("Klip animasi tidak lengkap di Pack")
		return
	print("[pack-test] klip=%d HASIL: OK" % animation.get_animation_list().size())
	quit(0)


func _licenses_present() -> bool:
	const BUNDLE := "res://licenses/LICENSES.txt"
	if not FileAccess.file_exists(BUNDLE):
		push_error("Bundel lisensi/kredit tidak masuk PCK: LICENSES.txt")
		return false
	var notices := FileAccess.get_file_as_string(BUNDLE)
	for required in [
		"A-SEKAI — ORIGINAL WORK RIGHTS NOTICE",
		"CC0 1.0 Universal",
		"Copyright (c) 2020-present GDQuest",
		"Universal Animation Library 2 [Standard]",
		"the upstream notice and full CC0 legal code are reproduced below",
	]:
		if not notices.contains(required):
			push_error("Bagian wajib hilang dari LICENSES.txt: " + required)
			return false
	return true
