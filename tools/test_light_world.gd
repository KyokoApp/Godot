extends SceneTree
## Smoke test the grassy world, blue ripple orb, switch button, smooth flight, and analog.

const Field = preload("res://src/game/world/field.gd")
const UPDATE_RESUME := "user://in_game_update_resume.cfg"
const ORB_RADIUS := 0.24

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
	var switch_button := game.find_child("TransformSwitchButton", true, false) as Button
	var update_button := game.find_child("UpdateContentButton", true, false) as Button
	var field := game.get("_field") as Node3D
	var orbit := game.get("_orbit") as Node3D
	_check(player != null and not player is CharacterBody3D,
		"Player belum menjadi gumpalan cahaya tanpa rig")
	_check(field != null and game.get("_scenery") != null
		and game.get("_forest") != null and game.get("_grass") != null,
		"World utama tidak lengkap")
	_check(joystick != null and bool(joystick.get("input_enabled")),
		"Analog gerak tidak aktif")
	_check(update_button != null and update_button.is_visible_in_tree(),
		"Tombol update konten tidak tersedia di dalam game")
	_check(switch_button != null and switch_button.is_visible_in_tree(),
		"Tombol SWITCH transformasi tidak tersedia")
	if switch_button != null:
		_check(switch_button.anchor_left == 1.0 and switch_button.anchor_right == 1.0,
			"Tombol SWITCH tidak dipasang di sisi kanan")
		_check(switch_button.custom_minimum_size.x >= 90.0
			and switch_button.custom_minimum_size.y >= 90.0,
			"Tombol SWITCH tidak cukup besar untuk aksi mobile")
	_check(game.find_child("GameplayHUD", true, false) == null,
		"HUD lama masih dibuat")
	_check(game.find_child("Mira", true, false) == null,
		"NPC masih dibuat")
	_check(game.find_children("*", "AnimationPlayer", true, false).is_empty(),
		"Rig/animasi masih dibuat di scene utama")

	var light_visual := player.get_node_or_null("BlueLightVisual") if player != null else null
	var orb := light_visual.get_node_or_null("BlueWaveOrb") as MeshInstance3D \
		if light_visual != null else null
	var aura := light_visual.get_node_or_null("BlueAura") as OmniLight3D \
		if light_visual != null else null
	var shadow := player.get_node_or_null("HoverShadow") as MeshInstance3D \
		if player != null else null
	_check(light_visual != null and orb != null and orb.mesh is SphereMesh,
		"Gumpalan cahaya kecil belum memakai bola 3D")
	_check(orb != null and (orb.mesh as SphereMesh).radius <= 0.30,
		"Bola cahaya terlalu besar")
	_check(orb != null and orb.material_override is ShaderMaterial,
		"Permukaan bola tidak memakai shader gelombang halus")
	_check(aura != null and aura.light_color.b > aura.light_color.r * 1.5,
		"Aura karakter tidak berwarna biru")
	_check(aura != null and aura.omni_range <= 2.0,
		"Jangkauan aura biru terlalu besar")
	_check(shadow != null and shadow.mesh != null,
		"Bayangan gumpalan/cahaya di rumput tidak ada")
	_check(player != null and not bool(player.get("is_flying")),
		"Karakter seharusnya mulai dalam wujud gumpalan di rumput")

	if player != null and field != null and switch_button != null:
		var ground_height := float(field.call("surface_height",
			player.global_position.x, player.global_position.z))
		var grounded_center_gap := player.global_position.y - ground_height
		_check(grounded_center_gap >= 0.25 and grounded_center_gap <= 0.31,
			"Gumpalan tidak mulai tepat di atas permukaan rumput")
		_check(shadow != null and absf(shadow.global_position.y - ground_height - 0.025) < 0.01,
			"Bayangan gumpalan tidak menempel pada medan")

		var initial_y := player.global_position.y
		switch_button.emit_signal("pressed")
		_check(bool(player.get("is_flying")), "Tombol SWITCH tidak mengaktifkan wujud terbang")
		_check(float(player.get("flight_blend")) < 0.1,
			"Transformasi langsung meloncat tanpa transisi halus")
		var previous_y := initial_y
		var largest_step := 0.0
		for _frame in range(72):
			await physics_frame
			var current_y := player.global_position.y
			largest_step = maxf(largest_step, absf(current_y - previous_y))
			previous_y = current_y
		_check(largest_step < 0.09,
			"Transformasi naik terlalu mendadak, bukan smooth")
		_check(float(player.get("flight_blend")) >= 0.98,
			"Cahaya tidak selesai berubah menjadi wujud terbang")
		ground_height = float(field.call("surface_height",
			player.global_position.x, player.global_position.z))
		var flight_bottom_gap := player.global_position.y - ground_height - ORB_RADIUS
		_check(flight_bottom_gap >= 1.10,
			"Cahaya terbang terlalu dekat/menembus permukaan tanah")
		_check(shadow != null and absf(shadow.global_position.y - ground_height - 0.025) < 0.01,
			"Bayangan tidak tertinggal di permukaan saat cahaya terbang")

		var bob_min := INF
		var bob_max := -INF
		for _frame in range(170):
			await physics_frame
			var ground := float(field.call("surface_height",
				player.global_position.x, player.global_position.z))
			var center_height := player.global_position.y - ground
			bob_min = minf(bob_min, center_height)
			bob_max = maxf(bob_max, center_height)
		_check(bob_max - bob_min >= 0.055 and bob_max - bob_min <= 0.13,
			"Gerak naik-turun cahaya terbang tidak lembut/terlihat")

		var before_landing := player.global_position.y
		switch_button.emit_signal("pressed")
		_check(not bool(player.get("is_flying")), "Tombol SWITCH tidak memilih wujud gumpalan")
		var max_landing_step := 0.0
		previous_y = before_landing
		for _frame in range(90):
			await physics_frame
			var current_y := player.global_position.y
			max_landing_step = maxf(max_landing_step, absf(current_y - previous_y))
			previous_y = current_y
		_check(max_landing_step < 0.09,
			"Transformasi turun terasa mendadak, bukan smooth")
		_check(float(player.get("flight_blend")) <= 0.02,
			"Transformasi kembali ke gumpalan tidak selesai")

		var start := Vector2(player.global_position.x, player.global_position.z)
		joystick.set("direction", Vector2(1.0, 0.0))
		for _frame in range(30):
			await physics_frame
		var finish := Vector2(player.global_position.x, player.global_position.z)
		_check(start.distance_to(finish) > 0.7, "Analog tidak menggerakkan cahaya")
		_check(Field.is_inside(finish.x, finish.y, 0.0),
			"Gumpalan keluar dari pulau saat digerakkan")
		ground_height = float(field.call("surface_height", finish.x, finish.y))
		_check(player.global_position.y - ground_height >= 0.25
			and player.global_position.y - ground_height <= 0.31,
			"Jarak gumpalan ke rumput berubah saat bergerak analog")
		_check(light_visual != null and float(light_visual.get("motion_strength")) > 0.05,
			"Permukaan cahaya tidak merespons gerak analog")
		joystick.set("direction", Vector2.ZERO)

	var return_position := Vector2(2.75, -3.5)
	if player != null and orbit != null and switch_button != null:
		player.global_position.x = return_position.x
		player.global_position.z = return_position.y
		player.call("set_flying", true, true)
		switch_button.set("flying_mode", true)
		orbit.set("yaw", 0.9)
		orbit.set("pitch", 0.72)
		orbit.set("distance", 9.0)
		var saved := bool(game.call("_save_resume_state"))
		_check(saved, "Posisi, wujud, dan kamera tidak tersimpan sebelum membuka updater")
		if saved:
			var resumed := scene.instantiate() as Node3D
			root.add_child(resumed)
			var resumed_player := resumed.get("_player") as Node3D
			var resumed_orbit := resumed.get("_orbit") as Node3D
			_check(resumed_player != null and Vector2(
				resumed_player.global_position.x,
				resumed_player.global_position.z).distance_to(return_position) < 0.001,
				"Posisi player tidak dipulihkan setelah kembali dari updater")
			_check(resumed_player != null and bool(resumed_player.get("is_flying"))
				and float(resumed_player.get("flight_blend")) >= 0.99,
				"Wujud cahaya terbang tidak dipulihkan setelah kembali dari updater")
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
	print("[light-world-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
