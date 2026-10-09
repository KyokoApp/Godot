extends SceneTree
## Render regression Run Zone: intro, speed level 20, Black Flash, Hollow Purple.

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
	var game := load("res://src/game/legacy_main.tscn").instantiate() as Node3D
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
	selector.call("_select_mode", 1)
	var world := game.get("_run_zone") as Node3D
	var orbit := game.get("_orbit") as Node3D
	_check(world != null, "Mode Run Zone tidak membuat world")
	if world == null:
		game.queue_free()
		quit(1)
		return
	var caster := world.get("caster") as Node3D
	var orb := world.get("spell_orb") as MeshInstance3D
	_check(caster != null and caster.global_position.y > 2.0,
		"Penyihir terbang tidak muncul pada shot intro")
	_check(orb != null and orb.visible, "Bola mantra tidak tampak pada shot intro")
	_check(float(orbit.get("pitch")) < 0.6,
		"Shot intro tidak memakai kamera third-person")
	_check(absf(wrapf(float(orbit.get("yaw")) - PI, -PI, PI)) < 0.1,
		"Kamera intro tidak menghadap penyihir di belakang")
	for node_name in ["_pet", "_speed_aura", "_foot_fire"]:
		var effect: Node = game.get(node_name)
		if effect != null:
			effect.set("visible", false)
			effect.set_process(false)
	for _frame in range(24):
		await physics_frame
	await _capture("run-zone-intro")
	for _frame in range(135):
		await physics_frame
	_check(str(world.get("phase")) == "running",
		"Run Zone tidak mulai setelah cinematic")
	_check(bool(player.get("endless_run_active")), "Auto-run tidak aktif saat render gameplay")
	_check(float(orbit.get("pitch")) < 0.6,
		"Shot lari menggunakan sudut top-down")
	_check(absf(wrapf(float(orbit.get("yaw")), -PI, PI)) < 0.10,
		"Kamera gameplay belum berada di belakang pemain dan menghadap jalur")
	await _capture("run-zone-third-person")

	var hud := game.get("_run_zone_hud") as Control
	var speed_button := hud.get("speed_button") as Button if hud != null else null
	_check(speed_button != null and speed_button.visible,
		"Tombol Speed Run Zone tidak terlihat")
	if speed_button != null:
		for _tap in range(RunZone.SPEED_LEVEL_LIMIT):
			speed_button.emit_signal("pressed")
			await physics_frame
	_check(int(world.get("speed_level")) == RunZone.SPEED_LEVEL_LIMIT,
		"Tes render gagal menaikkan speed ke level 20")
	var environment := (game.get_node("DuskEnvironment") as WorldEnvironment).environment
	_check(environment.adjustment_saturation < 0.01,
		"Grayscale tidak aktif pada Speed 20")
	var camera := orbit.get("camera") as Camera3D
	_check(camera != null and camera.fov > 86.0,
		"FOV tidak memberi kesan speed tinggi")
	await _capture("run-zone-speed-20-black-flash")

	player.global_position.z = -RunZone.HOLLOW_PURPLE_DISTANCE - 1.0
	for _frame in range(4):
		await process_frame
	var run_player := world.get("player") as Node3D
	var triggered := bool(world.get("hollow_purple_started"))
	var trigger_detail := (
		"phase=%s jarak=%.2fm z=%.2fm run=%s " % [
			str(world.get("phase")), float(world.get("distance_m")),
			player.global_position.z, str(game.get("_active_mode")),
		]
		+ "proses=%s paused=%s waktu=%.2f skala=%.2f wpz=%.2fm" % [
			str(world.is_processing()), str(game.get_tree().paused),
			float(world.get("elapsed_seconds")), Engine.time_scale,
			run_player.global_position.z if run_player != null else 0.0,
		]
	)
	_check(triggered, "Hollow Purple tidak mulai pada jarak pemicu (" + trigger_detail + ")")
	print("[run-zone-render-test] pemicu Hollow Purple: ", trigger_detail,
		" mulai=", triggered)
	var effects := world.get("effects") as Node3D
	for _frame in range(55):
		await physics_frame
	var purple_orb := effects.get("_orb") as Node3D
	_check(str(effects.get("phase")) == "charging",
		"Bola Hollow Purple tidak berada pada fase charge saat render")
	_check(purple_orb != null and purple_orb.is_visible_in_tree()
		and purple_orb.scale.x >= 6.0,
		"Bola Hollow Purple raksasa tidak tampak pada render charge")
	_check_orb_on_screen(purple_orb, camera, "charge")
	await _capture("run-zone-hollow-purple-charge")
	for _frame in range(150):
		await physics_frame
	_check(int(effects.get("impact_count")) == 1,
		"Hollow Purple tidak menghasilkan impact dalam render")
	_check(int(effects.get("slash_count")) >= 4,
		"Slash tebal tidak muncul saat impact Hollow Purple")
	_check(_visible_slash_centers(effects, camera) >= 3,
		"Slash Hollow Purple tidak terbaca di viewport saat impact")
	_check_orb_on_screen(purple_orb, camera, "impact")
	await _capture("run-zone-hollow-purple-impact")
	print("[run-zone-render-test] phase=", world.get("phase"),
		" speed=", world.get("current_speed"),
		" speed_level=", world.get("speed_level"),
		" camera_pitch=", orbit.get("pitch"))
	print("[run-zone-render-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	game.queue_free()
	for _frame in range(4):
		await process_frame
	quit(0 if _failures == 0 else 1)


func _visible_slash_centers(effects: Node3D, camera: Camera3D) -> int:
	if effects == null or camera == null:
		return 0
	var viewport_rect := camera.get_viewport().get_visible_rect()
	var visible_count := 0
	var slash_nodes := effects.get("_slashes") as Array
	for value in slash_nodes:
		var slash := value as MeshInstance3D
		if slash == null or not slash.is_visible_in_tree():
			continue
		var center := slash.global_position
		if not camera.is_position_behind(center) \
				and viewport_rect.has_point(camera.unproject_position(center)):
			visible_count += 1
	return visible_count


func _check_orb_on_screen(orb: Node3D, camera: Camera3D, label: String) -> void:
	if orb == null or camera == null:
		_check(false, "Kamera atau bola Hollow Purple hilang saat " + label)
		return
	var center := orb.global_position
	var screen_center := camera.unproject_position(center)
	var viewport_rect := camera.get_viewport().get_visible_rect()
	var edge := camera.unproject_position(
		center + camera.global_basis.x * orb.scale.x)
	var projected_width := absf(edge.x - screen_center.x) * 2.0
	_check(not camera.is_position_behind(center),
		"Bola Hollow Purple berada di belakang kamera saat " + label)
	_check(viewport_rect.has_point(screen_center),
		"Pusat bola Hollow Purple di luar frame saat " + label)
	_check(projected_width >= 30.0 and projected_width <= viewport_rect.size.x * 0.75,
		"Ukuran bola Hollow Purple di layar tidak terbaca saat " + label)
	print("[run-zone-render-test] orb ", label, " screen=", screen_center,
		" diameter=", projected_width)


func _capture(name: String) -> void:
	for _frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "user://%s-test.png" % name
	image.save_png(path)
	print("[run-zone-render-test] ", path, " ", image.get_width(), "x", image.get_height())
