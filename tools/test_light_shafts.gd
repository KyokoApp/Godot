extends SceneTree
const Shafts = preload("res://src/game/god_rays/light_shafts.gd")
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
	# Melihat sedikit di kiri-bawah matahari, jadi sinar datang dari sudut layar,
	# bukan tepat di tengah -- sekaligus menguji penghitungan arah sinar.
	camera.look_at(Shafts.Dusk.SUN_DIRECTION * 10.0 + Vector3(-3.0, -2.0, 0.0))
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var shafts := Shafts.new()
	shafts.camera = camera
	layer.add_child(shafts)
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	_check(shafts.visible, "Sinar matahari tidak muncul saat menghadap matahari")
	var on := root.get_texture().get_image()
	on.save_png("user://light-shafts-test.png")
	shafts.enabled = false
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var off := root.get_texture().get_image()
	var changed := 0
	for y in range(0, on.get_height(), 2):
		for x in range(0, on.get_width(), 2):
			if on.get_pixel(x, y).r > off.get_pixel(x, y).r + 0.003:
				changed += 1
	_check(changed > 10, "Shader sinar tidak menghasilkan cahaya")
	_check(not shafts.visible, "Sinar yang dimatikan masih terlihat")
	shafts.enabled = true
	camera.look_at(-Shafts.Dusk.SUN_DIRECTION)
	await process_frame
	await process_frame
	_check(not shafts.visible, "Sinar terlihat saat matahari di belakang kamera")
	# Tombol grafik harus mengubah efek langsung dan bertahan setelah setelan dimuat.
	var panel_script = load("res://src/game/performance_panel.gd") as GDScript
	var settings_path: String = panel_script.SETTINGS
	var had_settings := FileAccess.file_exists(settings_path)
	var saved := FileAccess.get_file_as_bytes(settings_path) if had_settings else PackedByteArray()
	var panel: VBoxContainer = panel_script.new()
	panel.set("rays", shafts)
	root.add_child(panel)
	var initial: bool = panel.get("rays_enabled")
	panel.call("toggle_rays")
	_check(shafts.enabled != initial, "Tombol grafis tidak mengubah sinar")
	var restored: VBoxContainer = panel_script.new()
	root.add_child(restored)
	_check(restored.get("rays_enabled") == not initial, "Setelan sinar tidak tersimpan")
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
	print("[light-shafts-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
