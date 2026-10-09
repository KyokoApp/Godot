extends SceneTree
## Smoke test: the active scene is a warm fire crossing a clean desert, not the old island.

const DesertWorld = preload("res://src/game/world/desert_world.gd")
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
	var desert := game.get("_desert") as Node3D
	var joystick := game.get("_joystick") as Control
	var fire := game.find_child("FireVisual", true, false) as Node3D
	var fire_light := game.find_child("FireLight", true, false) as OmniLight3D
	var update_button := game.find_child("UpdateContentButton", true, false) as Button
	_check(player != null and not player is CharacterBody3D,
		"Player memakai tubuh karakter, bukan api sederhana")
	_check(desert != null and desert.find_child("NearDunes", true, false) != null
		and desert.find_child("FarDunes", true, false) != null,
		"Terrain gurun bertingkat tidak lengkap")
	var camera_collision: StaticBody3D
	if desert != null:
		camera_collision = desert.find_child(
			"CameraGroundCollision", true, false) as StaticBody3D
	_check(camera_collision != null and camera_collision.collision_layer == 1,
		"Kamera tidak memiliki collider dune untuk mencegah clipping")
	var mesa_meshes := []
	if desert != null:
		mesa_meshes = desert.find_children("*Mesa*", "MeshInstance3D", true, false)
		mesa_meshes.append_array(
			desert.find_children("*Butte*", "MeshInstance3D", true, false))
	_check(mesa_meshes.size() >= 5, "Landmark mesa gurun tidak terbentuk")
	for old_node in [
		"Field", "Scenery", "Forest", "Grass", "Water", "Ocean", "Lake", "Island",
		"DuskEnvironment",
	]:
		_check(game.find_child(old_node, true, false) == null,
			"Node world lama masih dibuat: " + old_node)
	_check(joystick != null and bool(joystick.get("input_enabled")),
		"Analog gerak tidak aktif")
	_check(update_button != null and update_button.is_visible_in_tree(),
		"Tombol update konten tidak tersedia")
	_check(fire != null and fire_light != null,
		"Api realistis atau cahaya lokal tidak terbentuk")
	_check(fire_light != null and fire_light.light_color.r > fire_light.light_color.b,
		"Warna api belum hangat")
	_check(player == null or player.find_child("BlueFlameVisual", true, false) == null,
		"Visual api lama masih dipakai")
	_check(game.find_child("GameplayHUD", true, false) == null,
		"HUD lama masih dibuat")
	_check(game.find_child("Mira", true, false) == null,
		"NPC masih dibuat")
	_check(game.find_children("*", "AnimationPlayer", true, false).is_empty(),
		"Rig/animasi lama masih dibuat di scene utama")
	_check(absf(DesertWorld.terrain_height(0.0, 0.0)
		- DesertWorld.terrain_height(140.0, -92.0)) > 0.35,
		"Relief dune tidak berubah pada jarak berjalan")
	var nearby_min := 1e20
	var nearby_max := -1e20
	for local_z in range(-40, 41, 10):
		for local_x in range(-40, 41, 10):
			var local_height := DesertWorld.terrain_height(float(local_x), float(local_z))
			nearby_min = minf(nearby_min, local_height)
			nearby_max = maxf(nearby_max, local_height)
	_check(nearby_max - nearby_min > 3.0,
		"Dune lokal tidak cukup terlihat dari kamera pemain")

	if player != null and desert != null and joystick != null and fire != null:
		var start := Vector2(player.global_position.x, player.global_position.z)
		joystick.set("direction", Vector2(1.0, 0.0))
		for _frame in range(30):
			await physics_frame
		var finish := Vector2(player.global_position.x, player.global_position.z)
		_check(start.distance_to(finish) > 0.7, "Analog tidak menggerakkan player")
		_check(bool(desert.call("is_inside", finish.x, finish.y, 0.0)),
			"Player keluar dari area gurun yang dapat dijelajahi")
		_check(float(fire.get("motion_strength")) > 0.35,
			"Api tidak merespons kecepatan analog")
		var lean: Vector2 = fire.get("lean_vector")
		_check(lean.length() > 0.08, "Api tidak condong mengikuti arah gerak")
		joystick.set("direction", Vector2.ZERO)
		for _frame in range(24):
			await physics_frame
		_check(float(fire.get("motion_strength")) < 0.20,
			"Api tidak kembali tenang setelah player berhenti")

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
