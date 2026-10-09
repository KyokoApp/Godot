extends SceneTree
## HUD analog-only: tombol aksi hilang, gerak analog tetap responsif, panel utilitas tetap aman.

var _failures := 0
var _fingers: Dictionary = {}
var _last_drag: Dictionary = {}


func _init() -> void:
	Engine.max_physics_steps_per_frame = 32
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
	print("::error::", message)


func _touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	root.push_input(event, true)
	# Sentuhan pertama/terakhir di HP juga menghasilkan event mouse GUI.
	var first_finger := _fingers.is_empty() and pressed
	var last_finger := _fingers.size() == 1 and not pressed and _fingers.has(index)
	if first_finger or last_finger:
		var mouse := InputEventMouseButton.new()
		mouse.device = InputEvent.DEVICE_ID_EMULATION
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		mouse.position = point
		root.push_input(mouse, true)
	if pressed:
		_fingers[index] = true
	else:
		_fingers.erase(index)
	_last_drag[index] = point


func _drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	event.relative = point - _last_drag.get(index, point)
	_last_drag[index] = point
	root.push_input(event, true)


func _run() -> void:
	DirAccess.remove_absolute("user://hud_layout.cfg")
	var game := load("res://src/game/legacy_main.tscn").instantiate() as Node3D
	root.add_child(game)
	var player: CharacterBody3D = game.get("_player")
	for _frame in range(60):
		await physics_frame
		if player != null and player.is_on_floor():
			break
	_check(player != null and player.is_on_floor(), "Pemain tidak menyentuh tanah")
	if player == null:
		game.queue_free()
		await process_frame
		quit(1)
		return

	var stick: Control = game.get("_joystick")
	var orbit: Node3D = game.get("_orbit")
	var pet: Node3D = game.get("_pet")
	var fire_button: Button = game.get("_fire_button")
	var attack_button: Button = game.get("_attack")
	var jump_button: Button = game.get("_jump")
	var crouch_button: Button = game.get("_crouch")
	var speed_button: Button = game.get("_speed_button")
	var dash_button: Button = game.get("_dash")
	var action_buttons: Array[Button] = [attack_button, fire_button, jump_button,
		crouch_button, speed_button, dash_button]
	_check(stick != null and stick.visible and bool(stick.get("input_enabled")),
		"Analog tidak terlihat/aktif sebagai kontrol gameplay")
	for action_button in action_buttons:
		_check(action_button != null and not action_button.is_visible_in_tree()
			and action_button.disabled,
			"Tombol aksi masih terlihat atau aktif: " + str(action_button))
	_check(game.find_child("CharacterSwitcher", true, false) == null,
		"Pemilih karakter lama masih ada")
	_check(game.get("_minimap") == null, "Minimap lama masih ada")
	var layout_button: Button = game.get("_layout_button")
	var settings_button: Button = game.get("_settings")
	var catalog_button: Button = game.get("_catalog_button")
	_check(layout_button != null and not layout_button.is_visible_in_tree(),
		"Tombol editor layout HUD masih terlihat")
	_check(settings_button != null and settings_button.is_visible_in_tree(),
		"Tombol pengaturan utilitas ikut hilang")
	_check(catalog_button != null and catalog_button.is_visible_in_tree(),
		"Tombol katalog animasi utilitas ikut hilang")

	# Geser analog penuh ke bawah: tetap berlari, bukan beralih ke klip jalan mundur.
	var left := root.get_visible_rect().size * Vector2(0.22, 0.66)
	var fire_point := fire_button.get_global_rect().get_center()
	var start := Vector2(player.position.x, player.position.z)
	_touch(0, left, true)
	_drag(0, left + Vector2(0, 120))
	var down_direction: Vector2 = stick.get("direction")
	_check(down_direction.y > 0.9, "Analog penuh ke bawah tidak terbaca")
	# Jari kedua di bekas posisi tombol tembak tidak boleh memicu skill/tombol apa pun.
	_touch(1, fire_point, true)
	_check(not bool(pet.get("casting")), "Tombol TEMBAK tersembunyi masih bisa dipicu")
	for _frame in range(48):
		await physics_frame
	_check(player.gait == "Sprint_Loop",
		"Analog ke bawah saat lari masih memakai animasi jalan: " + player.gait)
	var travelled := Vector2(player.position.x - start.x,
		player.position.z - start.y).length()
	_check(travelled > 1.0, "Analog tidak menggerakkan pemain sambil berlari")
	_touch(1, fire_point, false)
	_touch(0, left + Vector2(0, 120), false)
	for _frame in range(30):
		await physics_frame
	_check(player.move_speed < 0.05, "Pemain tidak berhenti setelah analog dilepas")
	_check(not bool(pet.get("casting")), "Sentuhan pada HUD tersembunyi memulai casting")
	_check(orbit.get("_touches").is_empty(), "Jari input masih tertinggal di kamera")

	# Panel katalog adalah utilitas non-gameplay; saat terbuka, sentuhan tidak bergerak.
	var catalog: Button = game.get("_catalog_button")
	var panel: Control = game.get("_panel")
	_touch(12, catalog.get_global_rect().get_center(), true)
	_touch(12, catalog.get_global_rect().get_center(), false)
	_check(panel.visible, "Tombol katalog tidak membuka panel")
	var rows: Dictionary = panel.get("_rows")
	_check(rows.size() == 85, "Panel tidak memuat 85 klip: %d" % rows.size())
	var frozen := Vector2(player.position.x, player.position.z)
	var panel_touch := panel.get_global_rect().get_center() + Vector2(40, 40)
	_touch(14, panel_touch, true)
	_drag(14, panel_touch + Vector2(100, 0))
	var panel_direction: Vector2 = stick.get("direction")
	_check(panel_direction.is_zero_approx(), "Panel membiarkan analog ikut bergerak")
	_check(orbit.get("_touches").is_empty(), "Panel ikut memutar kamera")
	_touch(14, panel_touch + Vector2(100, 0), false)
	for _frame in range(6):
		await physics_frame
	var drift := Vector2(player.position.x - frozen.x, player.position.z - frozen.y).length()
	_check(drift < 0.05, "Pemain bergerak di belakang panel")
	var close_button: Button
	for node in panel.find_children("*", "Button", true, false):
		var candidate := node as Button
		if candidate.text == "TUTUP":
			close_button = candidate
	_check(close_button != null, "Tombol TUTUP tidak ada di panel")
	if close_button != null:
		var close_point := close_button.get_global_rect().get_center()
		_touch(15, close_point, true)
		_touch(15, close_point, false)
	_check(not panel.visible, "Panel tidak bisa ditutup")
	_check(stick.get("input_enabled") and orbit.get("input_enabled"),
		"Input tidak pulih setelah panel ditutup")

	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://hud-analog-test.png")
	DirAccess.remove_absolute("user://hud_layout.cfg")
	game.queue_free()
	await process_frame
	print("[hud-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
