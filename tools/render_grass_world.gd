extends SceneTree
## Mobile-renderer screenshots of the blue light orb grounded, flying, and moving.
## The captures double as a visual gate for the smooth switch and hover shadow.

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
	var switch_button := game.find_child("TransformSwitchButton", true, false) as Button
	var light_visual := player.get_node_or_null("BlueLightVisual") if player != null else null
	var shadow := player.get_node_or_null("HoverShadow") as MeshInstance3D if player != null else null
	if orbit == null or player == null or field == null or joystick == null \
			or switch_button == null or light_visual == null:
		_record_failure("Kamera, pulau, analog, switch, atau cahaya tidak terbentuk")
		game.queue_free()
		quit(1)
		return
	if game.get("_scenery") == null or game.get("_forest") == null or game.get("_grass") == null:
		_record_failure("Pemandangan, hutan, atau rumput asli tidak dipasang")
	if shadow == null or shadow.mesh == null:
		_record_failure("Bayangan untuk bola cahaya tidak dibangun")
	if bool(player.get("is_flying")):
		_record_failure("Gumpalan seharusnya mulai dekat permukaan rumput")

	orbit.set("yaw", 0.0)
	orbit.set("pitch", 0.48)
	orbit.set("distance", 8.0)
	for _frame in range(35):
		await physics_frame
	if not _camera_clear_of_ground(orbit, player, field, false):
		_record_failure("Kamera gameplay standar memotong medan atau kehilangan gumpalan")
	await _capture("grass-world-default-gameplay")

	orbit.set("yaw", 0.68)
	orbit.set("distance", 3.8)
	for _frame in range(35):
		await physics_frame
	if not _camera_clear_of_ground(orbit, player, field, false):
		_record_failure("Kamera close-up gumpalan memotong medan atau kehilangan bola")
	await _capture("grass-world-blob-ground")

	var start_y := player.global_position.y
	switch_button.emit_signal("pressed")
	await physics_frame
	if absf(player.global_position.y - start_y) > 0.09:
		_record_failure("Transformasi SWITCH dimulai dengan loncatan mendadak")
	var previous_y := player.global_position.y
	var largest_step := absf(previous_y - start_y)
	for _frame in range(76):
		await physics_frame
		var current_y := player.global_position.y
		largest_step = maxf(largest_step, absf(current_y - previous_y))
		previous_y = current_y
	if largest_step >= 0.09 or float(player.get("flight_blend")) < 0.98:
		_record_failure("Transformasi menjadi cahaya terbang tidak smooth atau tidak selesai")
	_check_flight_gap(field, player, shadow)
	if not _camera_clear_of_ground(orbit, player, field, true):
		_record_failure("Kamera close-up memotong medan atau kehilangan celah cahaya-bayangan")
	await _capture("grass-world-light-idle")

	var start := Vector2(player.global_position.x, player.global_position.z)
	joystick.set("direction", Vector2(1.0, 0.0))
	for _frame in range(36):
		await physics_frame
	var finish := Vector2(player.global_position.x, player.global_position.z)
	if start.distance_to(finish) < 0.7:
		_record_failure("Analog tidak menggerakkan cahaya terbang di atas pulau")
	_check_flight_gap(field, player, shadow)
	if float(light_visual.get("motion_strength")) < 0.25:
		_record_failure("Bola cahaya tidak merespons gerakan analog")
	if not _camera_clear_of_ground(orbit, player, field, true):
		_record_failure("Kamera saat cahaya bergerak kehilangan bola atau bayangan")
	joystick.set("direction", Vector2.ZERO)
	await _capture("grass-world-light-moving")
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
	var bottom_gap := player.global_position.y - ground_height - 0.24
	if bottom_gap < 0.72 or bottom_gap > 1.10:
		_record_failure("Bola cahaya terlalu dekat/tinggi dari rumput: celah %.2f m" % bottom_gap)
	if shadow == null or absf(shadow.global_position.y - ground_height - 0.025) > 0.01:
		_record_failure("Bayangan tidak menempel pada permukaan pulau")


func _camera_clear_of_ground(
	orbit: Node3D, player: Node3D, field: Node3D, check_flight_gap: bool
) -> bool:
	var camera := orbit.get("camera") as Camera3D
	var arm := orbit.get("arm") as SpringArm3D
	if camera == null or arm == null:
		return false
	var distance := float(orbit.get("distance"))
	var viewport_rect := camera.get_viewport().get_visible_rect()
	if not _light_markers_visible(camera, player, viewport_rect, check_flight_gap):
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


func _light_markers_visible(
	camera: Camera3D, player: Node3D, viewport_rect: Rect2, require_gap: bool
) -> bool:
	var orb_center := player.global_position
	var orb_screen_position := camera.unproject_position(orb_center)
	if camera.is_position_behind(orb_center) or not viewport_rect.has_point(orb_screen_position):
		return false
	var shadow := player.find_child("HoverShadow", true, false) as Node3D
	if shadow == null:
		return false
	var shadow_screen_position := camera.unproject_position(shadow.global_position)
	if camera.is_position_behind(shadow.global_position) \
			or not viewport_rect.has_point(shadow_screen_position):
		return false
	return not require_gap or orb_screen_position.distance_to(shadow_screen_position) >= 18.0


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
