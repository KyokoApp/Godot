extends SceneTree
## Render cinematic penyihir + kamera lari third-person untuk regresi Run Zone.

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
	var game := load("res://src/game/main.tscn").instantiate() as Node3D
	root.add_child(game)
	var player := game.get("_player") as CharacterBody3D
	for _frame in range(90):
		await physics_frame
		if player.is_on_floor():
			break
	var selector := game.get("_mode_selector") as Control
	_check(selector != null, "Selector mode tidak ditemukan")
	if selector == null:
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
	_check(absf(wrapf(float(orbit.get("yaw")), -PI, PI)) < 0.1,
		"Kamera intro tidak menghadap penyihir di belakang pemain")
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
	_check(absf(wrapf(float(orbit.get("yaw")) - PI, -PI, PI)) < 0.10,
		"Kamera gameplay belum berada di belakang pemain")
	await _capture("run-zone-third-person")
	print("[run-zone-render-test] phase=", world.get("phase"),
		" speed=", world.get("current_speed"),
		" camera_pitch=", orbit.get("pitch"))
	print("[run-zone-render-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	game.queue_free()
	for _frame in range(4):
		await process_frame
	quit(0 if _failures == 0 else 1)


func _capture(name: String) -> void:
	for _frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "user://%s-test.png" % name
	image.save_png(path)
	print("[run-zone-render-test] ", path, " ", image.get_width(), "x", image.get_height())
