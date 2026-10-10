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
	orbit.set("pitch", 0.60)
	orbit.set("distance", 58.0)
	for _frame in range(40):
		await physics_frame
	if _camera_clear_of_ground(orbit, player, desert, false):
		await _capture("desert-horizon")
	else:
		_record_failure("Kamera horizon menembus permukaan pasir")

	orbit.set("pitch", 0.42)
	orbit.set("distance", 8.0)
	for _frame in range(35):
		await physics_frame
	if _camera_clear_of_ground(orbit, player, desert):
		await _capture("desert-default-gameplay")
	else:
		_record_failure("Kamera gameplay default menembus permukaan pasir")

	orbit.set("yaw", 0.68)
	orbit.set("pitch", 0.42)
	orbit.set("distance", 8.0)
	for _frame in range(35):
		await physics_frame
	if _camera_clear_of_ground(orbit, player, desert):
		await _capture("desert-gameplay")
	else:
		_record_failure("Kamera gameplay standar menembus permukaan pasir")

	orbit.set("distance", 3.8)
	for _frame in range(35):
		await physics_frame
	if _camera_clear_of_ground(orbit, player, desert):
		await _capture("desert-fire-idle")
	else:
		_record_failure("Kamera close-up menembus permukaan pasir")

	joystick.set("direction", Vector2(1.0, 0.0))
	for _frame in range(36):
		await physics_frame
	if not _camera_clear_of_ground(orbit, player, desert):
		_record_failure("Kamera saat analog bergerak menembus pasir")
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


func _camera_clear_of_ground(
	orbit: Node3D, player: Node3D, desert: Node3D, check_fire_visibility: bool = true
) -> bool:
	var camera := orbit.get("camera") as Camera3D
	var arm := orbit.get("arm") as SpringArm3D
	if camera == null or arm == null:
		return false
	if check_fire_visibility:
		var fire_center := player.global_position + Vector3(0.0, 0.68, 0.0)
		var fire_screen_position := camera.unproject_position(fire_center)
		var viewport_rect := camera.get_viewport().get_visible_rect()
		if camera.is_position_behind(fire_center) or not viewport_rect.has_point(fire_screen_position):
			var message := "Api keluar dari bingkai kamera pada jarak %.2fm" % float(
				orbit.get("distance"))
			push_error(message)
			print("::error::", message)
			return false
	var desired_distance := float(orbit.get("distance"))
	var actual_distance := arm.global_position.distance_to(camera.global_position)
	print("[desert-render-test] arm=%.2fm / %.2fm" % [actual_distance, desired_distance])
	if actual_distance < desired_distance - 0.55:
		var blocked := "Arm kamera terpotong: %.2fm dari %.2fm" % [
			actual_distance, desired_distance]
		push_error(blocked)
		print("::error::", blocked)
		return false
	var focus_offset: Vector3 = orbit.get("focus_offset")
	var target := player.global_position + focus_offset + Vector3(0.0, arm.position.y, 0.0)
	var camera_position := camera.global_position
	for sample in range(1, 20):
		var point := camera_position.lerp(target, float(sample) / 20.0)
		var ground_y := float(desert.call("surface_height", point.x, point.z))
		if point.y < ground_y + 0.04:
			var clearance := point.y - ground_y
			var blocked := "Sinar kamera menembus pasir: %.2fm clearance di sample %d" % [
				clearance, sample]
			push_error(blocked)
			print("::error::", blocked)
			return false
	return true


func _record_failure(message: String) -> void:
	_failures += 1
	push_error(message)
	print("::error::", message)


func _fail(message: String) -> void:
	_record_failure(message)
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
