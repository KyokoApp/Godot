extends SceneTree
## Open the exported content pack in a fresh process and verify the active desert payload.

var _scene: PackedScene


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
	_scene = load("res://src/game/main.tscn") as PackedScene
	if _scene == null or not _scene.can_instantiate():
		return "Scene desert tidak ikut PCK"
	var sand: Texture2D = load("res://assets/desert/sand_albedo.png")
	if sand == null or sand.get_width() < 512:
		return "Tekstur pasir desert tidak ikut PCK"
	var ground_shader: Shader = load("res://src/game/desert_ground.gdshader")
	if ground_shader == null:
		return "Shader pasir tidak ikut PCK"
	var fire_shader: Shader = load("res://src/game/realistic_fire.gdshader")
	if fire_shader == null:
		return "Shader api hangat tidak ikut PCK"
	return ""


func _boot_scene() -> void:
	var marker := FileAccess.open("user://content_boot_pending", FileAccess.WRITE)
	marker.store_string("test")
	marker.close()
	var game := _scene.instantiate() as Node3D
	root.add_child(game)
	for _frame in range(5):
		await process_frame

	var problem := ""
	var player := game.get("_player") as Node3D
	var desert := game.find_child("Desert", true, false)
	var fire: Node
	if player != null:
		fire = player.find_child("FireVisual", true, false)
	if FileAccess.file_exists("user://content_boot_pending"):
		problem = "Konten tidak mengonfirmasi boot"
	elif player == null or fire == null:
		problem = "Player api realistis tidak dibangun"
	elif player is CharacterBody3D:
		problem = "Player masih memakai tubuh/rig karakter"
	elif fire.find_child("FireLight", true, false) == null:
		problem = "Cahaya lokal api tidak ada"
	elif desert == null or desert.find_child("NearSand", true, false) == null:
		problem = "Bidang pasir datar tidak dimuat"
	elif game.find_child("Field", true, false) != null \
			or game.find_child("Scenery", true, false) != null \
			or game.find_child("Forest", true, false) != null \
			or game.find_child("Grass", true, false) != null \
			or game.find_child("Water", true, false) != null \
			or game.find_child("Ocean", true, false) != null \
			or game.find_child("DuskEnvironment", true, false) != null:
		problem = "World pulau/laut/rumput lama masih dibuat"
	elif game.find_child("GameplayHUD", true, false) != null \
			or game.find_child("AnimationPanel", true, false) != null:
		problem = "UI atau panel karakter lama masih muncul"
	elif game.find_child("MovementAnalog", true, false) == null:
		problem = "Analog gerak tidak ada"
	elif game.find_child("UpdateContentButton", true, false) == null:
		problem = "Tombol update in-game tidak ada"
	elif not game.find_children("*", "AnimationPlayer", true, false).is_empty():
		problem = "Rig animasi lama masih ikut world utama"

	if not problem.is_empty():
		_fail(problem)
		return
	print("[pack-test] desert + api realistis + analog HASIL: OK")
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
