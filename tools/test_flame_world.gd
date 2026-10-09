extends SceneTree
## Smoke test scene utama yang tersisa: world, api player, dan analog saja.

const Field = preload("res://src/game/world/field.gd")
const UPDATE_RESUME := "user://in_game_update_resume.cfg"

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
	print("::error::", message)


func _run() -> void:
	DirAccess.remove_absolute(UPDATE_RESUME)
	var scene: PackedScene = load("res://src/game/main.tscn")
	_check(scene != null, "Scene utama tidak bisa dimuat")
	if scene == null:
		quit(1)
		return
	var game := scene.instantiate() as Node3D
	root.add_child(game)
	for _frame in range(8):
		await physics_frame
	var player := game.get("_player") as Node3D
	var joystick := game.get("_joystick") as Control
	var update_button := game.find_child("UpdateContentButton", true, false) as Button
	_check(player != null and not player is CharacterBody3D,
		"Player belum diganti menjadi node api tanpa rig")
	_check(game.get("_field") != null and game.get("_scenery") != null
		and game.get("_forest") != null and game.get("_grass") != null,
		"World utama tidak lengkap")
	_check(joystick != null and bool(joystick.get("input_enabled")),
		"Analog gerak tidak aktif")
	_check(update_button != null and update_button.is_visible_in_tree(),
		"Tombol update konten tidak tersedia di dalam game")
	_check(game.find_child("GameplayHUD", true, false) == null,
		"HUD lama masih dibuat")
	_check(game.find_child("Mira", true, false) == null,
		"NPC masih dibuat")
	_check(game.find_children("*", "AnimationPlayer", true, false).is_empty(),
		"Rig/animasi masih dibuat di scene utama")

	if player != null and joystick != null:
		var flame := player.get_node_or_null("BlueFlameVisual")
		_check(flame != null, "Visual api biru kecil tidak ada")
		_check(flame != null and flame.get_node_or_null("BlueFlameLight") != null,
			"Player tidak memiliki cahaya api biru")
		var start := Vector2(player.global_position.x, player.global_position.z)
		joystick.set("direction", Vector2(1.0, 0.0))
		for _frame in range(30):
			await physics_frame
		var finish := Vector2(player.global_position.x, player.global_position.z)
		_check(start.distance_to(finish) > 0.7, "Analog tidak menggerakkan player")
		_check(Field.is_inside(finish.x, finish.y, 0.0),
			"Api keluar dari pulau saat digerakkan")
		joystick.set("direction", Vector2.ZERO)

	var orbit := game.get("_orbit") as Node3D
	var return_position := Vector2(2.75, -3.5)
	if player != null and orbit != null:
		player.global_position = Vector3(
			return_position.x, player.global_position.y, return_position.y)
		orbit.set("yaw", 0.9)
		orbit.set("pitch", 0.72)
		orbit.set("distance", 9.0)
		var saved := bool(game.call("_save_resume_state"))
		_check(saved, "Posisi/kamera tidak tersimpan sebelum membuka updater")
		if saved:
			var resumed := scene.instantiate() as Node3D
			root.add_child(resumed)
			var resumed_player := resumed.get("_player") as Node3D
			var resumed_orbit := resumed.get("_orbit") as Node3D
			_check(resumed_player != null and Vector2(
				resumed_player.global_position.x,
				resumed_player.global_position.z).distance_to(return_position) < 0.001,
				"Posisi player tidak dipulihkan setelah kembali dari updater")
			_check(resumed_orbit != null
				and is_equal_approx(float(resumed_orbit.get("yaw")), 0.9)
				and is_equal_approx(float(resumed_orbit.get("pitch")), 0.72)
				and is_equal_approx(float(resumed_orbit.get("distance")), 9.0),
				"Kamera tidak dipulihkan setelah kembali dari updater")
			for _frame in range(3):
				await process_frame
			resumed.queue_free()
	else:
		_check(false, "Player/kamera tidak tersedia untuk tes pemulihan updater")

	DirAccess.remove_absolute(UPDATE_RESUME)
	game.queue_free()
	await process_frame
	print("[flame-world-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
