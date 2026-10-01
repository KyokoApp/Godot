extends SceneTree
## HUD sentuh: analog, serangan pet, lompat, jongkok, boost, dan panel animasi —
## semuanya lewat viewport supaya urutan _input/GUI asli ikut diuji.

var _failures := 0
var _fingers: Dictionary = {}


func _init() -> void:
	# Vulkan software di CI hanya sanggup beberapa frame per detik; tanpa ini
	# engine cuma memajukan 8 tick fisika per frame sehingga 240 tick menunggu
	# puluhan frame render (~2 menit). Batas ini hanya soal catch-up, fisika tetap
	# satu tick per langkah.
	Engine.max_physics_steps_per_frame = 32
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
	# Di HP sungguhan Godot mengubah sentuhan jari PERTAMA menjadi mouse emulasi.
	# Button bawaan (jongkok, lompat, katalog, TUTUP) hanya bereaksi pada event itu,
	# sedangkan kontrol sentuh sendiri (analog, rune, orbit) justru mengabaikan
	# emulasi — persis seperti yang diuji di sini.
	var first_finger := _fingers.is_empty() and pressed and not canceled
	var last_finger := _fingers.size() == 1 and not pressed and _fingers.has(index)
	if first_finger or last_finger:
		var mouse := InputEventMouseButton.new()
		mouse.device = InputEvent.DEVICE_ID_EMULATION
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		mouse.position = point
		root.push_input(mouse, true)
	if pressed and not canceled:
		_fingers[index] = true
	else:
		_fingers.erase(index)


func _drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	root.push_input(event, true)


func _run() -> void:
	var game := load("res://src/game/main.tscn").instantiate() as Node3D
	root.add_child(game)
	var player: CharacterBody3D = game.get("_player")
	for frame in range(60):
		await physics_frame
		if player != null and player.is_on_floor():
			break
	_check(player != null and player.is_on_floor(), "Pemain tidak menyentuh tanah")
	var attack: Button = game.get("_attack")
	var jump: Button = game.get("_jump")
	var crouch: Button = game.get("_crouch")
	var catalog: Button = game.get("_catalog_button")
	var panel: Control = game.get("_panel")
	var stick: Control = game.get("_joystick")
	var orbit: Node3D = game.get("_orbit")
	var visual: Node3D = game.get("_visual")
	var pet: Node3D = game.get("_pet")
	var pet_id := pet.get_instance_id()
	_check(attack.size.is_equal_approx(Vector2(88, 88)), "Tombol serangan bukan 88px")
	_check(game.find_child("CharacterSwitcher", true, false) == null,
		"Pemilih karakter lama masih ada")
	_check(game.get("_minimap") == null, "Minimap lama masih ada")
	# Boost.
	var speed_button: Control = game.get("_speed_button")
	_touch(9, speed_button.get_global_rect().get_center(), true)
	_touch(9, speed_button.get_global_rect().get_center(), false)
	_check(player.boosted, "Tombol speed tidak menyalakan boost")
	_check(orbit.get("_touches").is_empty(), "Tombol speed ikut mengorbit kamera")
	_touch(9, speed_button.get_global_rect().get_center(), true)
	_touch(9, speed_button.get_global_rect().get_center(), false)
	_check(not player.boosted, "Boost tidak kembali normal")
	# Jongkok.
	_touch(10, crouch.get_global_rect().get_center(), true)
	_touch(10, crouch.get_global_rect().get_center(), false)
	_check(player.crouching and crouch.text == "BERDIRI", "Tombol jongkok tidak bekerja")
	_touch(10, crouch.get_global_rect().get_center(), true)
	_touch(10, crouch.get_global_rect().get_center(), false)
	_check(not player.crouching and crouch.text == "JONGKOK", "Jongkok tidak dibatalkan")
	# Lompat: animasi menolak lebih dulu, badan menyusul.
	var before_velocity := player.velocity.y
	_touch(11, jump.get_global_rect().get_center(), true)
	_touch(11, jump.get_global_rect().get_center(), false)
	_check(player.get("_jump_delay") > 0.0, "Lompat tidak memulai fase tolakan")
	_check(visual.clip == "Jump_Start", "Animasi tolakan bukan Jump_Start")
	_check(is_equal_approx(player.velocity.y, before_velocity),
		"Badan melompat sebelum animasi menolak")
	for frame in range(20):
		await physics_frame
	_check(player.velocity.y > 1.0 or not player.is_on_floor(), "Badan tidak ikut melompat")
	for frame in range(90):
		await physics_frame
		if player.is_on_floor():
			break
	_check(player.is_on_floor(), "Pemain tidak mendarat kembali")
	# Serangan pet + analog jalan bersamaan.
	var left := root.get_visible_rect().size * Vector2(0.22, 0.66)
	var hit := attack.get_global_rect().get_center()
	_touch(0, left, true)
	_drag(0, left + Vector2(86, 0))
	_touch(1, hit, true)
	_check(pet.get("casting"), "Jari kedua gagal casting sambil jalan")
	_check(stick.get("direction").x > 0.9, "Attack menghentikan joystick")
	_check(orbit.get("_touches").is_empty(), "Attack ikut memutar kamera")
	var start := player.position
	for frame in range(12):
		await physics_frame
	var travelled := Vector2(player.position.x - start.x, player.position.z - start.z).length()
	_check(travelled > 0.2, "Karakter berhenti saat attack ditahan")
	_touch(1, hit, false)
	_touch(0, left, false)
	for frame in range(24):
		await physics_frame
	_check(player.move_speed < 0.05, "Pemain tidak berhenti setelah jari diangkat")
	# Panel katalog animasi.
	_touch(12, catalog.get_global_rect().get_center(), true)
	_touch(12, catalog.get_global_rect().get_center(), false)
	_check(panel.visible, "Tombol katalog tidak membuka panel")
	var rows: Dictionary = panel.get("_rows")
	_check(rows.size() == 85, "Panel tidak memuat 85 klip: %d" % rows.size())
	var row: Button = rows["Sword_Regular_Combo"]
	panel.call("_scroll_to", "Sword_Regular_Combo")
	for frame in range(3):
		await process_frame
	var row_point := row.get_global_rect().get_center()
	if panel.get_global_rect().has_point(row_point) and row.is_visible_in_tree():
		_touch(13, row_point, true)
		_touch(13, row_point, false)
	else:
		row.pressed.emit()
	await process_frame
	_check(visual.clip == "Sword_Regular_Combo", "Baris panel tidak memutar klipnya")
	_check(pet.get_instance_id() == pet_id, "Panel membuat pet duplikat")
	var frozen := Vector2(player.position.x, player.position.z)
	_touch(14, panel.get_global_rect().get_center() + Vector2(40, 40), true)
	_drag(14, panel.get_global_rect().get_center() + Vector2(120, 40))
	_check(stick.get("direction").is_zero_approx(), "Sentuh panel menggerakkan pemain")
	_check(orbit.get("_touches").is_empty(), "Panel ikut memutar kamera")
	_touch(14, panel.get_global_rect().get_center() + Vector2(120, 40), false)
	for frame in range(6):
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
		var point := close_button.get_global_rect().get_center()
		_touch(15, point, true)
		_touch(15, point, false)
		_check(not panel.visible, "Panel tidak bisa ditutup")
	_check(stick.input_enabled and orbit.input_enabled, "Input tidak pulih setelah panel")
	game.queue_free()
	for frame in range(4):
		await process_frame
	print("[hud-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
