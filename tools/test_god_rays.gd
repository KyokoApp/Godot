extends SceneTree
const Rays = preload("res://src/game/god_rays/moon_rays.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.01, 0.015, 0.025)
	world.add_child(env)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.look_at(Rays.Night.MOON_DIRECTION)
	var rays := Rays.new()
	rays.camera = camera
	camera.add_child(rays)
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	_check(rays.visible and rays.strength > 0, "Moon rays absent when facing moon")
	var on := root.get_texture().get_image()
	on.save_png("user://moon-rays-test.png")
	rays.enabled = false
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var off := root.get_texture().get_image()
	var changed := 0
	for y in range(0, on.get_height(), 2):
		for x in range(0, on.get_width(), 2):
			if on.get_pixel(x, y).r > off.get_pixel(x, y).r + 0.003:
				changed += 1
	_check(changed > 10, "God ray shader produced no visible light")
	_check(not rays.visible, "Disabled rays still visible")
	rays.enabled = true
	camera.look_at(-Rays.Night.MOON_DIRECTION)
	await process_frame
	await process_frame
	_check(not rays.visible, "Rays visible behind camera")
	camera.look_at(Rays.Night.MOON_DIRECTION)
	# Fully blocking geometry must suppress the radial light source.
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(20, 20, 0.1)
	wall.mesh = box
	camera.add_child(wall)
	wall.position.z = -2
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var blocked := root.get_texture().get_image()
	rays.enabled = false
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var blocked_off := root.get_texture().get_image()
	_check(blocked.get_pixel(240, 135).is_equal_approx(blocked_off.get_pixel(240, 135)),
		"Rays shine through opaque geometry")
	# The graphics switch must affect the live effect and survive settings reload.
	var panel_script = load("res://src/game/performance_panel.gd") as GDScript
	var settings_path: String = panel_script.SETTINGS
	var had_settings := FileAccess.file_exists(settings_path)
	var saved := FileAccess.get_file_as_bytes(settings_path) if had_settings else PackedByteArray()
	var panel: VBoxContainer = panel_script.new()
	panel.set("rays", rays)
	root.add_child(panel)
	var initial: bool = panel.get("rays_enabled")
	panel.call("toggle_rays")
	_check(rays.enabled != initial, "Graphics toggle did not change rays")
	var restored: VBoxContainer = panel_script.new()
	root.add_child(restored)
	_check(restored.get("rays_enabled") == not initial, "Rays setting was not persisted")
	panel.queue_free()
	restored.queue_free()
	if had_settings:
		var file := FileAccess.open(settings_path, FileAccess.WRITE)
		file.store_buffer(saved)
		file.close()
	else:
		DirAccess.remove_absolute(settings_path)
	world.queue_free()
	await process_frame
	print("[god-rays-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
