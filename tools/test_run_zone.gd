extends SceneTree
## Tes integrasi Run Zone: selector, intro caster, kamera third-person, auto-run,
## percepatan bertahap, tanah endless, dan pulang ke home.

const MainScene = preload("res://src/game/main.tscn")
const RunZone = preload("res://src/game/world/run_zone.gd")

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
	var game := MainScene.instantiate() as Node3D
	root.add_child(game)
	var player := game.get("_player") as CharacterBody3D
	for _frame in range(90):
		await physics_frame
		if player.is_on_floor():
			break

	var selector := game.get("_mode_selector") as Control
	_check(selector != null, "Selector mode tidak ditemukan")
	if selector == null:
		game.queue_free()
		quit(1)
		return
	selector.call("open")
	game.call("_apply_input_state")
	var cards: Array = selector.get("_cards")
	_check(cards.size() == 3, "Selector mode tidak memuat tiga kartu")
	if cards.size() >= 2:
		_check(str(cards[1].get_meta("mode_id", "")) == "run_zone",
			"Kartu kedua bukan Run Zone")
	selector.call("_select_mode", 1)

	var orbit := game.get("_orbit") as Node3D
	var world := game.get("_run_zone") as Node3D
	_check(str(game.get("_active_mode")) == "run_zone",
		"Memilih Run Zone tidak mengganti mode")
	_check(world != null, "Run Zone tidak membuat dunianya")
	_check(bool(game.get("_run_zone_intro_active")),
		"Intro kamera tidak mengunci input sementara")
	_check(orbit != null and float(orbit.get("pitch")) < 0.6,
		"Kamera Run Zone memakai sudut top-down, bukan third-person")
	_check(absf(wrapf(float(orbit.get("yaw")), -PI, PI)) < 0.1,
		"Shot intro tidak mulai menghadap penyihir di belakang pemain")
	_check(not bool(player.get("endless_run_active")),
		"Pemain mulai berlari sebelum intro mantra selesai")
	_check(not bool(game.get("_joystick").get("input_enabled")),
		"Analog bisa mengganggu cinematic intro")
	if world == null:
		game.queue_free()
		quit(1)
		return

	var caster := world.get("caster") as Node3D
	var caster_visual := world.get("caster_visual") as Node3D
	var orb := world.get("spell_orb") as MeshInstance3D
	_check(caster != null and caster.global_position.y > 2.0,
		"Penyihir terbang tidak muncul di belakang pemain")
	_check(caster_visual != null and str(caster_visual.get("gait")) == "NinjaJump_Idle_Loop",
		"Animasi melayang penyihir tidak dipakai")
	if caster_visual != null:
		var cast_layer: Node = caster_visual.get("cast_layer")
		_check(cast_layer != null and bool(cast_layer.get("holding_pose")),
			"Penyihir tidak menahan pose mantra")
	_check(orb != null and orb.visible, "Efek bola mantra tidak tampak saat intro")
	var ground: Node3D = world.get("ground")
	_check(ground != null and ground.has_method("surface_height"),
		"Dunia endless tidak memakai bidang tanah Run Zone")

	for _frame in range(150):
		await physics_frame
	var run_started := str(world.get("phase")) == "running"
	_check(run_started, "Intro tidak beralih ke auto-run")
	_check(bool(player.get("endless_run_active")), "Auto-run pemain belum aktif")
	_check(float(orbit.get("pitch")) < 0.6,
		"Kamera third-person tidak dipertahankan setelah intro")
	_check(absf(wrapf(float(orbit.get("yaw")) - PI, -PI, PI)) < 0.10,
		"Kamera tidak menyapu ke belakang pemain untuk third-person")
	var previous_speed := float(world.get("current_speed"))
	var previous_z := player.global_position.z
	for _frame in range(50):
		await physics_frame
	_check(player.global_position.z < previous_z - 1.0,
		"Pemain tidak terus berlari maju")
	_check(player.is_on_floor(), "Pemain jatuh dari tanah endless Run Zone")
	_check(str(player.get("gait")) == "Sprint_Loop",
		"Gait lari cepat tidak dipertahankan dalam auto-run")
	_check(float(player.get("move_speed")) > 2.0,
		"Kecepatan auto-run tidak diterapkan pada badan pemain")
	var hud := game.get("_run_zone_hud") as Control
	var detail := hud.get("_detail") as Label if hud != null else null
	_check(detail != null and detail.text.contains("m/s"),
		"HUD Run Zone tidak menampilkan laju lari")
	var observed_speed := float(world.get("current_speed"))
	_check(observed_speed > previous_speed,
		"Laju Run Zone tidak bertambah seiring waktu")

	var home_camera_distance := float(game.get("_home_camera_state").get("distance", 0.0))
	var back := InputEventKey.new()
	back.pressed = true
	back.keycode = KEY_ESCAPE
	game.call("_input", back)
	await physics_frame
	_check(str(game.get("_active_mode")) == "hub", "Run Zone tidak pulang ke home")
	_check(game.get("_run_zone") == null, "Dunia Run Zone tidak dibersihkan saat pulang")
	_check(not bool(player.get("endless_run_active")), "Auto-run tertinggal setelah pulang")
	_check(game.get("_npc") != null, "NPC home tidak dipulihkan setelah Run Zone")
	_check(absf(float(orbit.get("distance")) - home_camera_distance) < 0.1,
		"State kamera home tidak dipulihkan")

	game.queue_free()
	await process_frame
	print("[run-zone-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
