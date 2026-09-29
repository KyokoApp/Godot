extends SceneTree
## Injeksi lewat viewport agar urutan _input/GUI asli ikut diuji, bukan callback saja.

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _touch(index: int, point: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event, true)


func _drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	root.push_input(event, true)


func _run() -> void:
	var scene: PackedScene = load("res://src/game/main.tscn")
	var game: Node3D = scene.instantiate()
	root.add_child(game)
	for frame in range(4):
		await physics_frame
	var attack: Button = game.get("_attack")
	var stick: Control = game.get("_joystick")
	var pet: Node3D = game.get("_pet")
	var orbit: Node3D = game.get("_orbit")
	var player: CharacterBody3D = game.get("_player")
	var left := root.get_visible_rect().size * Vector2(0.22, 0.66)
	var hit := attack.get_global_rect().get_center()
	_check(attack.size.is_equal_approx(Vector2(128, 128)), "Attack tidak bulat 128px")
	_check(attack.text.is_empty(), "Teks debug attack belum dihapus")
	_check(not game.get("_performance").is_visible_in_tree(), "Setting belum tersembunyi")
	_touch(0, left, true)
	_drag(0, left + Vector2(86, 0))
	_touch(1, hit, true)
	_check(pet.get("casting"), "Jari kedua gagal casting sambil jalan")
	_check(stick.get("direction").x > 0.9, "Attack menghentikan joystick")
	_check(orbit.get("_touches").is_empty(), "Attack ikut memutar kamera")
	pet.set("cooldown", 0.0)
	var mouse := InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = hit
	root.push_input(mouse, true)
	_check(pet.get("projectiles").is_empty() and pet.get("casting"),
		"Emulasi mouse menggandakan/melewati windup")
	var start := player.position
	for frame in range(12):
		await physics_frame
	_check(player.position.x > start.x + 0.2, "Karakter berhenti saat attack ditahan")
	_check(pet.get("projectiles").size() == 1, "Casting bergerak gagal menembak")
	var camera_point := root.get_visible_rect().size * Vector2(0.65, 0.45)
	_touch(2, camera_point, true)
	var yaw: float = orbit.get("yaw")
	_drag(2, camera_point + Vector2(40, 0))
	_check(not is_equal_approx(yaw, orbit.get("yaw")), "Jari ketiga tidak bisa orbit")
	_touch(2, camera_point, false)
	_check(stick.get("_finger") == 0 and attack.get("_finger") == 1,
		"Lepas kamera membatalkan kontrol lain")
	_drag(1, Vector2.ZERO)
	_touch(1, Vector2.ZERO, false)
	_check(attack.get("_finger") == -1, "Attack tersangkut setelah lepas di luar tombol")
	_touch(0, left, false)
	# Urutan terbalik: attack dulu, lalu joystick.
	_touch(4, hit, true)
	_touch(5, left, true)
	_drag(5, left + Vector2(86, 0))
	_check(pet.get("casting"), "Serangan berikutnya tidak bekerja")
	_check(stick.get("direction").x > 0.9, "Joystick gagal saat attack ditekan lebih dulu")
	_touch(4, hit, false, true)
	_touch(5, left, false)
	_check(attack.get("_finger") == -1, "Touch cancel tidak mereset attack")
	await _test_settings(game)
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://hud-clean-test.png")
	game.queue_free()
	await process_frame
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
	print("[hud-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)


func _test_settings(game: Node3D) -> void:
	var settings: Button = game.get("_settings")
	var attack: Button = game.get("_attack")
	var stick: Control = game.get("_joystick")
	var orbit: Node3D = game.get("_orbit")
	var panel: Control = game.get("_performance")
	var point := settings.get_global_rect().get_center()
	_touch(6, point, true)
	_touch(6, point, false)
	_check(panel.is_visible_in_tree(), "Ikon grafik gagal membuka drawer")
	_check(not attack.visible and not stick.get("input_enabled"), "Menu tidak memblokir combat")
	_check(not orbit.get("input_enabled"), "Kamera masih aktif ketika menu terbuka")
	if "--render" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://hud-settings-test.png")
	_touch(6, point, true)
	_touch(6, point, false)
	_check(not panel.is_visible_in_tree() and attack.visible, "Ikon tidak menutup drawer")
	_check(stick.get("input_enabled") and orbit.get("input_enabled"), "Kontrol tidak pulih")
	_touch(7, attack.get_global_rect().get_center(), true)
	attack.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(attack.get("_finger") == -1, "Attack tersangkut setelah aplikasi kehilangan fokus")
