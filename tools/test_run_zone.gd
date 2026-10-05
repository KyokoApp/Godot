extends SceneTree
## Tes Run Zone: jalur tiga petak, speed button, Black Flash, Hollow Purple, dan pulang.

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
	var environment := (game.get_node("DuskEnvironment") as WorldEnvironment).environment
	var home_environment_brightness := environment.adjustment_brightness
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
	var home_camera := orbit.get("camera") as Camera3D if orbit != null else null
	var home_camera_fov := home_camera.fov if home_camera != null else 65.0
	var world := game.get("_run_zone") as Node3D
	var hud := game.get("_run_zone_hud") as Control
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
	if world == null or hud == null:
		game.queue_free()
		quit(1)
		return

	var caster := world.get("caster") as Node3D
	var caster_visual := world.get("caster_visual") as Node3D
	var caster_orb := world.get("spell_orb") as MeshInstance3D
	_check(caster != null and caster.global_position.y > 2.0,
		"Penyihir terbang tidak muncul di belakang pemain")
	_check(caster_visual != null and str(caster_visual.get("gait")) == "NinjaJump_Idle_Loop",
		"Animasi melayang penyihir tidak dipakai")
	if caster_visual != null:
		var cast_layer: Node = caster_visual.get("cast_layer")
		_check(cast_layer != null and bool(cast_layer.get("holding_pose")),
			"Penyihir tidak menahan pose mantra")
	_check(caster_orb != null and caster_orb.visible,
		"Efek bola mantra tidak tampak saat intro")
	var ground: Node3D = world.get("ground")
	_check(ground != null and ground.has_method("surface_height"),
		"Dunia endless tidak memakai bidang tanah Run Zone")
	var track: Node3D = world.get("track")
	_check(track != null and is_equal_approx(float(track.get("path_width")), 6.0),
		"Jalur batu tidak selebar tiga petak")
	if track != null:
		var rocks := track.get("rocks") as MultiMeshInstance3D
		_check(rocks != null and rocks.multimesh.instance_count >= 60,
			"Batu sisi jalur tidak dibuat dalam batch ringan")
	var speed_button := hud.get("speed_button") as Button
	_check(speed_button != null and not speed_button.is_visible_in_tree(),
		"Tombol Speed terlihat saat intro sinematik")

	for _frame in range(150):
		await physics_frame
	_check(str(world.get("phase")) == "running", "Intro tidak beralih ke auto-run")
	_check(bool(player.get("endless_run_active")), "Auto-run pemain belum aktif")
	_check(float(orbit.get("pitch")) < 0.6,
		"Kamera third-person tidak dipertahankan setelah intro")
	_check(absf(wrapf(float(orbit.get("yaw")) - PI, -PI, PI)) < 0.10,
		"Kamera tidak menyapu ke belakang pemain untuk third-person")
	_check(speed_button != null and speed_button.is_visible_in_tree() and not speed_button.disabled,
		"Tombol SPEED +1 tidak aktif setelah intro")
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
	var detail := hud.get("_detail") as Label
	_check(detail != null and detail.text.contains("m/s"),
		"HUD Run Zone tidak menampilkan laju lari")
	var observed_speed := float(world.get("current_speed"))
	_check(observed_speed > previous_speed,
		"Laju Run Zone tidak bertambah seiring waktu")

	var before_tap := float(world.get("current_speed"))
	speed_button.emit_signal("pressed")
	await physics_frame
	_check(int(world.get("speed_level")) == 1,
		"Satu tap SPEED tidak menambah satu level")
	_check(float(world.get("current_speed")) > before_tap,
		"Satu tap SPEED tidak menaikkan laju pemain")
	for _tap in range(19):
		speed_button.emit_signal("pressed")
		await physics_frame
	_check(int(world.get("speed_level")) == 20,
		"Tombol SPEED tidak berhenti tepat di level 20")
	_check(bool(world.get("black_flash_triggered")),
		"Level 20 tidak memicu Black Flash")
	_check(speed_button.disabled, "Tombol Speed tidak menandai level maksimum")
	var flash_label := hud.get("_flash_label") as Label
	_check(flash_label != null and flash_label.visible and flash_label.text == "BLACK FLASH!",
		"Burst kartun BLACK FLASH tidak muncul")
	_check(environment.adjustment_saturation < 0.01,
		"Dunia tidak berubah menjadi monokrom di Speed 20")
	_check(home_camera != null and home_camera.fov > 86.0,
		"Kamera tidak memberi rasa laju di Speed 20")
	var natural_speed := float((player.get("visual") as Node3D).call(
		"natural_speed", "Sprint_Loop"))
	var expected_playback := float(world.get("current_speed")) / maxf(natural_speed, 0.01)
	_check(absf(float(player.get("speed_scale")) - expected_playback) < 0.18,
		"Playback Sprint tidak mengikuti laju sehingga kaki bisa meluncur")
	_check(float(player.get("speed_scale")) <= 3.0,
		"Skala Sprint melampaui batas klip yang aman")

	player.global_position.z = -RunZone.HOLLOW_PURPLE_DISTANCE
	for _frame in range(2):
		await physics_frame
	_check(bool(world.get("hollow_purple_started")),
		"Hollow Purple tidak muncul setelah menempuh jarak tertentu")
	var effects: Node3D = world.get("effects")
	for _frame in range(205):
		await physics_frame
	_check(int(effects.get("impact_count")) == 1,
		"Bola Hollow Purple tidak menghantam area sekitar")
	_check(int(effects.get("slash_count")) >= 4,
		"Efek sayatan tidak ikut muncul saat impact")
	_check(int(effects.get("destroyed_rock_count")) > 0,
		"Impact Hollow Purple tidak menghancurkan batu sisi jalur")
	var destroyed_sections: Array = track.get("destroyed_sections")
	_check(not destroyed_sections.is_empty(),
		"Area batu yang dihancurkan tidak disimpan untuk jalur endless")

	var home_camera_state: Dictionary = game.get("_home_camera_state")
	var home_camera_distance := float(home_camera_state.get("distance", 0.0))
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
	_check(home_camera != null and absf(home_camera.fov - home_camera_fov) < 0.1,
		"Field of view kamera home tidak dipulihkan")
	_check(environment.adjustment_saturation > 0.9,
		"Warna home tidak dipulihkan setelah Black Flash")
	_check(absf(environment.adjustment_brightness - home_environment_brightness) < 0.01,
		"Kecerahan home tidak dipulihkan setelah Black Flash")

	game.queue_free()
	await process_frame
	print("[run-zone-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
