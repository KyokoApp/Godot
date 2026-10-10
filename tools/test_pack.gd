extends SceneTree
## Pack dibuka dalam proses baru; pastikan payload minimal bisa boot tanpa UI/rig lama.

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
		return "Scene world-only tidak ikut PCK"
	var meadow: Texture2D = load("res://assets/nature/meadow_cover.png")
	if meadow == null or meadow.get_width() <= 0:
		return "Tekstur medan tidak ikut PCK"
	var tree: PackedScene = load("res://assets/nature/models/CommonTree_1.gltf")
	if tree == null or not tree.can_instantiate():
		return "Model pepohonan dunia tidak ikut PCK"
	var flame_shader: Shader = load("res://src/game/realistic_fire.gdshader")
	if flame_shader == null:
		return "Shader api hangat realistis tidak ikut PCK"
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
	var flame: Node
	if player != null:
		flame = player.get_node_or_null("FireVisual")
	if FileAccess.file_exists("user://content_boot_pending"):
		problem = "Konten tidak mengonfirmasi boot"
	elif player == null or flame == null:
		problem = "Player api realistis tidak dibangun"
	elif player is CharacterBody3D:
		problem = "Player masih memakai tubuh/rig karakter"
	elif flame.get_node_or_null("FireLight") == null:
		problem = "Cahaya hangat player tidak ada"
	elif player.get_node_or_null("HoverShadow") == null:
		problem = "Bayangan untuk api melayang tidak ada"
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
	print("[pack-test] pulau hijau + api realistis melayang + analog HASIL: OK")
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
