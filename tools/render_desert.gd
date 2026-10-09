extends SceneTree
## Mobile-renderer captures for the active desert and the velocity-responsive fire.

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://src/game/main.tscn") as PackedScene
	if scene == null:
		_fail("Scene desert tidak bisa dimuat")
		return
	var game := scene.instantiate() as Node3D
	root.add_child(game)
	for _frame in range(30):
		await physics_frame
	var orbit := game.get("_orbit") as Node3D
	var player := game.get("_player") as Node3D
	var desert := game.get("_desert") as Node3D
	if orbit == null or player == null or desert == null:
		_fail("World, player, atau kamera desert tidak terbentuk")
		return
	var joystick := game.get("_joystick") as Control
	if joystick == null:
		_fail("Analog tidak tersedia untuk uji api bergerak")
		return
	orbit.set("yaw", 0.0)
	orbit.set("pitch", 0.24)
	orbit.set("distance", 58.0)
	for _frame in range(40):
		await physics_frame
	await _capture("desert-horizon")

	orbit.set("yaw", 0.68)
	orbit.set("pitch", 0.42)
	orbit.set("distance", 8.0)
	for _frame in range(35):
		await physics_frame
	await _capture("desert-gameplay")

	orbit.set("distance", 3.8)
	for _frame in range(35):
		await physics_frame
	await _capture("desert-fire-idle")

	joystick.set("direction", Vector2(1.0, 0.0))
	for _frame in range(36):
		await physics_frame
	var fire := player.find_child("FireVisual", true, false)
	if fire == null or float(fire.get("motion_strength")) < 0.25:
		_fail("Api tidak bereaksi saat analog mendorong player")
	joystick.set("direction", Vector2.ZERO)
	await _capture("desert-fire-moving")
	for _frame in range(24):
		await physics_frame

	print("[desert-render-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	game.queue_free()
	for _frame in range(3):
		await process_frame
	quit(0 if _failures == 0 else 1)


func _fail(message: String) -> void:
	_failures += 1
	push_error(message)
	print("::error::", message)
	quit(1)


func _capture(name: String) -> void:
	for _frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "user://%s.png" % name
	if image.save_png(path) != OK:
		_fail("Screenshot tidak bisa disimpan: " + path)
		return
	print("[desert-render-test] ", path, " ", image.get_width(), "x", image.get_height())
