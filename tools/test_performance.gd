extends SceneTree

const PerfPanel = preload("res://src/game/performance_panel.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _run() -> void:
	var existed := FileAccess.file_exists(PerfPanel.SETTINGS)
	var saved := FileAccess.get_file_as_string(PerfPanel.SETTINGS) if existed else ""
	var scene: PackedScene = load("res://src/game/main.tscn")
	var game: Node3D = scene.instantiate()
	root.add_child(game)
	await process_frame
	var panel: PerfPanel = game.get("_performance")
	panel.light_mode = true
	panel.shadows_enabled = false
	panel.grass_enabled = true
	panel.uncapped = false
	panel.apply_settings()
	_check(is_equal_approx(root.scaling_3d_scale, 0.75), "Mode ringan gagal")
	_check(Engine.max_fps == 60, "Batas FPS salah")
	_check(not panel.sun.shadow_enabled, "Bayangan tidak mati")
	panel.toggle_quality()
	_check(is_equal_approx(root.scaling_3d_scale, 1.0), "Mode normal gagal")
	panel.toggle_grass()
	_check(not panel.grass.visible and not panel.grass.is_processing(),
		"Tes rumput tidak menghentikan render dan streaming")
	panel.toggle_grass()
	_check(panel.grass.visible and panel.grass.is_processing(), "Rumput tidak pulih")
	panel.toggle_shadows()
	_check(panel.sun.shadow_enabled, "Toggle bayangan gagal")
	panel.toggle_limit()
	_check(Engine.max_fps == 0, "Mode FPS bebas tidak menghapus batas aplikasi")
	var config := ConfigFile.new()
	_check(config.load(PerfPanel.SETTINGS) == OK, "Pengaturan tidak tersimpan")
	_check(config.get_value("graphics", "uncapped", false) == true, "Nilai tersimpan salah")
	var orbit: Node3D = game.get("_orbit")
	var event := InputEventScreenTouch.new()
	event.index = 6
	event.pressed = true
	event.position = panel.get_global_rect().get_center()
	orbit._input(event)
	_check(orbit.get("_touches").is_empty(), "Tombol grafik ikut menggerakkan kamera")
	var character: Node3D = game.get("_visual")
	_check(character.find_child("BlueFlameRobe", true, false) == null, "Jubah belum dihapus")
	var visible_meshes := 0
	for child in character.find_children("*", "MeshInstance3D", true, false):
		if child.visible:
			visible_meshes += 1
	_check(visible_meshes > 0, "Mannequin asli tidak tampil")
	game.queue_free()
	await process_frame
	_check(Engine.max_fps == 0 and is_equal_approx(root.scaling_3d_scale, 1.0),
		"Pengaturan render bocor setelah keluar game")
	if existed:
		var file := FileAccess.open(PerfPanel.SETTINGS, FileAccess.WRITE)
		file.store_string(saved)
		file.close()
	else:
		DirAccess.remove_absolute(PerfPanel.SETTINGS)
	print("[performance-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
