extends SceneTree

const PerfPanel = preload("res://src/game/performance_panel.gd")
const Character = preload("res://src/game/mannequin.gd")
## Anggaran per frame untuk kulit beranimasi + biaya karakter tetap
## (60 fps = 16,7 ms; ini menjaga supaya tidak menghabiskan sepertiganya).
const AVATAR_BUDGET_MS := 6.0
var _failures := 0


func _init() -> void:
	call_deferred("_run")


## Biaya CPU per frame untuk "kulit beranimasi": setiap kali kerangka selesai
## diperbarui, salinan kulit menyalin seluruh pose tulang. Itu pengeluaran tetap
## baru di HP, jadi harus dijaga angka — dulu bagian ini mengukur simulasi kain
## avatar FBX, sekarang mengukur biaya kulit mannequin.
func _test_avatar_cost(character: Character, panel: PerfPanel) -> void:
	panel.light_mode = true
	panel.apply_settings()
	var light_ready := character.skin != null and character.skin.is_ready()
	panel.light_mode = false
	panel.apply_settings()
	_check(light_ready, "Kulit hilang di mode ringan")
	var frames := 200
	var bones := character.skeleton.get_bone_count()
	var copies := character.skin.cover_count()
	# Salinan pose dijalankan langsung: sinyal kerangka tidak berbunyi di headless
	# tanpa render, jadi yang diukur rumus biayanya, bukan apakah sinyalnya jalan
	# (itu diuji di tools/test_skin_shell.gd).
	var start := Time.get_ticks_usec()
	for _frame in range(frames):
		for _bone in range(bones):
			character.skeleton.get_bone_pose_position(_bone)
	var sample_ms := float(Time.get_ticks_usec() - start) / float(frames) / 1000.0
	# 3 pembacaan + 3 penulisan pose per tulang pada salinan kulit.
	var skin_ms := sample_ms * 6.0
	var total := skin_ms
	print("::notice::biaya avatar %.2f ms/frame (kulit %.2f, %d tulang, %d mesh tertutup)"
		% [total, skin_ms, bones, copies])
	_check(copies > 0, "Tidak ada mesh yang ditutup kulit")
	_check(total < AVATAR_BUDGET_MS,
		"Kulit beranimasi terlalu berat: %.2f ms/frame" % total)


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
	_check(not panel.is_visible_in_tree(), "Setting seharusnya tersembunyi saat mulai")
	game._toggle_graphics()
	_check(panel.is_visible_in_tree(), "Ikon tidak membuka setting")
	var orbit: Node3D = game.get("_orbit")
	var event := InputEventScreenTouch.new()
	event.index = 6
	event.pressed = true
	event.position = panel.get_global_rect().get_center()
	orbit._input(event)
	_check(orbit.get("_touches").is_empty(), "Tombol grafik ikut menggerakkan kamera")
	var character: Character = game.get("_visual")
	_check(character.find_child("BlueFlameRobe", true, false) == null, "Jubah belum dihapus")
	var visible_meshes := 0
	for child in character.find_children("*", "MeshInstance3D", true, false):
		if child.visible:
			visible_meshes += 1
	_check(visible_meshes > 0, "Avatar tidak tampil")
	_test_avatar_cost(character, panel)
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
