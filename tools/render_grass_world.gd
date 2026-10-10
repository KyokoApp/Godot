extends SceneTree
## Mobile-renderer screenshots of the restored grass island and the airborne fire.
## The captures double as a visual gate: keep both the flame and its ground shadow
## inside the gameplay frame, with a visible gap, rather than trusting height alone.

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://src/game/main.tscn") as PackedScene
	if scene == null:
		_record_failure("Scene pulau hijau tidak bisa dimuat")
		quit(1)
		return
	var game := scene.instantiate() as Node3D
	root.add_child(game)
	for _frame in range(30):
		await physics_frame

	var orbit := game.get("_orbit") as Node3D
	var player := game.get("_player") as Node3D
	var field := game.get("_field") as Node3D
	var joystick := game.get("_joystick") as Control
	var fire := player.get_node_or_null("FireVisual") if player != null else null
	var shadow := player.get_node_or_null("HoverShadow") as MeshInstance3D if player != null else null
	if orbit == null or player == null or field == null or joystick == null:
		_record_failure("Kamera, pulau, player, atau analog tidak terbentuk")
		game.queue_free()
		quit(1)
		return
	if game.get("_scenery") == null or game.get("_forest") == null or game.get("_grass") == null:
		_record_failure("Pemandangan, hutan, atau rumput asli tidak dipasang")
	if fire == null or shadow == null or shadow.mesh == null:
		_record_failure("Api realistis atau bayangan hover tidak dibangun")
	else:
		_check_flight_gap(field, player, shadow)

	orbit.set("yaw", 0.0)
	orbit.set("pitch", 0.48)
	orbit.set("distance", 8.0)
	for _frame in range(35):
		await physics_frame
	if not _camera_clear_of_ground(orbit, player, field, true):
		_record_failure("Kamera gameplay standar memotong medan atau kehilangan api/bayangan")
	await _capture("grass-world-default-gameplay")

	orbit.set("yaw", 0.68)
	for _frame in range(35):
		await physics_frame
	if not _camera_clear_of_ground(orbit, player, field, true):
		_record_failure("Kamera sudut kedua memotong medan atau kehilangan api/bayangan")
	await _capture("grass-world-gameplay")

	orbit.set("distance", 3.8)
	for _frame in range(35):
		await physics_frame
	if not _camera_clear_of_ground(orbit, player, field, true):
		_record_failure("Kamera close-up memotong medan atau kehilangan celah api-bayangan")
	await _capture("grass-world-fire-idle")

	var start := Vector2(player.global_position.x, player.global_position.z)
	joystick.set("direction", Vector2(1.0, 0.0))
	for _frame in range(36):
		await physics_frame
	var finish := Vector2(player.global_position.x, player.global_position.z)
	if start.distance_to(finish) < 0.7:
		_record_failure("Analog tidak menggerakkan api di atas pulau")
	if shadow != null:
		_check_flight_gap(field, player, shadow)
	if fire == null or float(fire.get("motion_strength")) < 0.25:
		_record_failure("Api tidak merespons gerakan analog")
	if not _camera_clear_of_ground(orbit, player, field, true):
		_record_failure("Kamera saat api bergerak memotong medan atau kehilangan api/bayangan")
	joystick.set("direction", Vector2.ZERO)
	await _capture("grass-world-fire-moving")
	for _frame in range(24):
		await physics_frame

	print("[grass-render-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	game.queue_free()
	for _frame in range(3):
		await process_frame
	quit(0 if _failures == 0 else 1)


func _check_flight_gap(field: Node3D, player: Node3D, shadow: MeshInstance3D) -> void:
	var ground_height := float(field.call("surface_height",
		player.global_position.x, player.global_position.z))
	var gap := player.global_position.y - ground_height
	if gap < 1.1 or gap > 1.3:
		_record_failure("Jarak api ke rumput di luar 1,1–1,3 m: %.2f m" % gap)
	if absf(shadow.global_position.y - ground_height - 0.025) > 0.01:
		_record_failure("Bayangan hover tidak menempel pada permukaan pulau")


func _camera_clear_of_ground(
	orbit: Node3D, player: Node3D, field: Node3D, check_shadow: bool
) -> bool:
	var camera := orbit.get("camera") as Camera3D
	var arm := orbit.get("arm") as SpringArm3D
	if camera == null or arm == null:
		return false
	var distance := float(orbit.get("distance"))
	var viewport_rect := camera.get_viewport().get_visible_rect()
	if not _flight_markers_visible(camera, player, viewport_rect, check_shadow):
		return false
	var actual_distance := arm.global_position.distance_to(camera.global_position)
	print("[grass-render-test] arm=%.2fm / %.2fm" % [actual_distance, distance])
	if actual_distance < distance - 0.55:
		return false
	var camera_position := camera.global_position
	var target := arm.global_position
	for sample in range(1, 20):
		var point := camera_position.lerp(target, float(sample) / 20.0)
		var ground_y := float(field.call("surface_height", point.x, point.z))
		if point.y < ground_y + 0.04:
			return false
	return true


func _flight_markers_visible(
	camera: Camera3D, player: Node3D, viewport_rect: Rect2, check_shadow: bool
) -> bool:
	var fire := player.get_node_or_null("FireVisual") as Node3D
	if fire == null or not fire.has_method("flame_center_position"):
		return false
	var fire_center: Vector3 = fire.call("flame_center_position")
	var fire_screen_position := camera.unproject_position(fire_center)
	if camera.is_position_behind(fire_center) or not viewport_rect.has_point(fire_screen_position):
		return false
	if not check_shadow:
		return true
	var shadow := player.find_child("HoverShadow", true, false) as Node3D
	if shadow == null:
		return false
	var shadow_screen_position := camera.unproject_position(shadow.global_position)
	if camera.is_position_behind(shadow.global_position) \
			or not viewport_rect.has_point(shadow_screen_position):
		return false
	return fire_screen_position.distance_to(shadow_screen_position) >= 24.0


func _record_failure(message: String) -> void:
	_failures += 1
	push_error(message)
	print("::error::", message)


func _capture(name: String) -> void:
	for _frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "user://%s.png" % name
	if image.save_png(path) != OK:
		_record_failure("Screenshot tidak bisa disimpan: " + path)
		return
	print("[grass-render-test] ", path, " ", image.get_width(), "x", image.get_height())
