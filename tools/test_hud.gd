extends SceneTree
## HUD sentuh: analog, serangan pet, lompat, jongkok, boost, dan panel animasi —
## semuanya lewat viewport supaya urutan _input/GUI asli ikut diuji.

var _failures := 0
var _fingers: Dictionary = {}
var _last_drag: Dictionary = {}


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
	_last_drag[index] = point


func _drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	# Perangkat asli mengisi relative; ScrollContainer memakai selisih posisi.
	event.relative = point - _last_drag.get(index, point)
	_last_drag[index] = point
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
	var fire: Button = game.get("_fire_button")
	var jump: Button = game.get("_jump")
	var crouch: Button = game.get("_crouch")
	var catalog: Button = game.get("_catalog_button")
	var panel: Control = game.get("_panel")
	var stick: Control = game.get("_joystick")
	var orbit: Node3D = game.get("_orbit")
	var visual: Node3D = game.get("_visual")
	var pet: Node3D = game.get("_pet")
	var pet_id := pet.get_instance_id()
	_check(attack.size.is_equal_approx(Vector2(136, 136)), "Tombol serang bukan 136px")
	_check(attack.get("caption") == "SERANG", "Tombol serang tidak berlabel SERANG")
	_check(fire.get("caption") == "TEMBAK", "Tombol tembak api tidak berlabel")
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
	_check(player.crouching and crouch.get("caption") == "BERDIRI",
		"Tombol jongkok tidak bekerja")
	_touch(10, crouch.get_global_rect().get_center(), true)
	_touch(10, crouch.get_global_rect().get_center(), false)
	_check(not player.crouching and crouch.get("caption") == "JONGKOK",
		"Jongkok tidak dibatalkan")
	# Serangan combo: tiap tekan ganti klip, lalu berputar dari awal lagi.
	# Combo sekarang dua pukulan; Melee_Hook dipindah jadi animasi DASH.
	var attack_point := attack.get_global_rect().get_center()
	for expected in ["Punch_Jab", "Punch_Cross", "Punch_Jab", "Punch_Cross"]:
		_touch(2, attack_point, true)
		_touch(2, attack_point, false)
		_check(visual.clip == expected,
			"Combo tidak berurutan: harusnya %s, dapat %s" % [expected, visual.clip])
	_check(int(player.get("combo_index")) == 0, "Indeks combo tidak berputar")
	_check(orbit.get("_touches").is_empty(), "Tombol serang ikut memutar kamera")
	# Dash: dorongan jauh lebih cepat dari lari biasa, dengan cooldown supaya
	# tidak bisa dipakai berulang tanpa jeda. Animasi TIDAK berganti klip: yang
	# berubah cuma kecepatan main (satu langkah diperlambat).
	stick.set("direction", Vector2.RIGHT)
	for frame in range(24):
		await physics_frame
	var speed_before_dash: float = player.get("move_speed")
	var dash_button: Button = game.get("_dash")
	var dash_point := dash_button.get_global_rect().get_center()
	_touch(20, dash_point, true)
	_touch(20, dash_point, false)
	_check(visual.gait == "Sprint_Loop",
		"Dash tidak memakai gait lari cepat: %s" % visual.gait)
	for frame in range(3):
		await physics_frame
	_check(player.move_speed > speed_before_dash + 1.5,
		"Dash tidak mempercepat badan: %.2f -> %.2f" % [speed_before_dash, player.move_speed])
	_check(float(player.get("dash_cooldown")) > 0.0, "Dash tidak memasang cooldown")
	stick.set("direction", Vector2.ZERO)
	for frame in range(30):
		await physics_frame
	_check(visual.gait.ends_with("_Loop") or visual.gait == "Idle_Loop",
		"Setelah dash animasi tidak kembali ke gait: " + visual.gait)
	# Lompat: langsung melompat, animasi tolakan menempel di badan yang sudah naik.
	var before_y := player.position.y
	_touch(11, jump.get_global_rect().get_center(), true)
	_touch(11, jump.get_global_rect().get_center(), false)
	_check(player.velocity.y > 1.0, "Lompat tidak langsung mendorong badan")
	_check(visual.clip == "Jump_Start", "Animasi tolakan bukan Jump_Start")
	var climbed := false
	var flown := false
	for frame in range(60):
		await physics_frame
		if player.position.y > before_y + 0.05:
			climbed = true
		if visual.clip == "Jump_Loop":
			flown = true
		if player.is_on_floor() and climbed:
			break
	_check(climbed, "Badan tidak naik setelah lompat")
	_check(flown, "Klip melayang Jump_Loop tidak pernah dipakai di udara")
	# Setelah mendarat, animasi harus cepat kembali ke gait, bukan diam di klip
	# mendarat sampai selesai (keluhan: "kayak jalan tapi gak gerak").
	var relaxed := false
	for frame in range(40):
		await physics_frame
		if not visual.is_busy():
			relaxed = true
			break
	_check(relaxed, "Animasi tidak kembali ke gait setelah mendarat")
	var landing_gait: String = player.gait
	_check(landing_gait == "Idle_Loop" or landing_gait.ends_with("_Loop"),
		"Gait setelah mendarat tidak masuk akal: " + landing_gait)
	# Diuji juga: saat diam, yang diputar memang klip Idle.
	_check(visual.gait == "Idle_Loop",
		"Setelah mendarat, klip yang diputar bukan Idle: " + visual.gait)
	# Lari -> lompat -> lari: klip mendarat harus DILEWATI supaya tidak ada jeda
	# pose jongkok/patung di tengah lari.
	stick.set("direction", Vector2.RIGHT)
	for frame in range(40):
		await physics_frame
	var running_speed := float(player.get("move_speed"))
	_check(running_speed > 1.5, "Pemain tidak berlari sebelum lompat: %.2f" % running_speed)
	# Ketinggian diukur TEPAT sebelum lompat, bukan di titik muncul: pulau 1 km
	# bergelombang (padang 100 m dulu rata), jadi pemain yang lari menurun
	# memang mendarat lebih rendah dari tempat ia mulai bergerak.
	var takeoff_y := player.position.y
	_touch(11, jump.get_global_rect().get_center(), true)
	_touch(11, jump.get_global_rect().get_center(), false)
	var landing_clip := ""
	var landed := false
	for frame in range(80):
		await physics_frame
		if player.is_on_floor() and player.position.y > takeoff_y - 1.0:
			landing_clip = str(visual.clip)
			landed = true
			break
	_check(landed, "Pemain berlari tidak mendarat kembali")
	_check(landing_clip != "Jump_Land",
		"Masih memutar klip mendarat saat berlari: " + landing_clip)
	_check(landing_clip.ends_with("_Loop"),
		"Setelah mendarat sambil lari animasi tidak lanjut ke gait: " + landing_clip)
	_check(not visual.is_busy(), "Animasi terkunci setelah mendarat sambil lari")
	stick.set("direction", Vector2.ZERO)
	for frame in range(30):
		await physics_frame
	# Tembakan api pet + analog jalan bersamaan.
	var left := root.get_visible_rect().size * Vector2(0.22, 0.66)
	var hit := fire.get_global_rect().get_center()
	_touch(0, left, true)
	_drag(0, left + Vector2(86, 0))
	_touch(1, hit, true)
	_check(pet.get("casting"), "Jari kedua gagal casting sambil jalan")
	_check(stick.get("direction").x > 0.9, "Tombol tembak menghentikan joystick")
	_check(orbit.get("_touches").is_empty(), "Tombol tembak ikut memutar kamera")
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
	var window: Control = panel.find_child("AnimationWindow", true, false)
	var view_size := root.get_visible_rect().size
	_check(window != null, "Jendela panel animasi tidak terbentuk")
	if window != null:
		_check(window.size.x <= view_size.x * 0.95 and window.size.y <= view_size.y * 0.85,
			"Panel animasi masih memenuhi layar: %s" % window.size)
		_check(window.size.y > 200.0, "Jendela panel terlalu kecil: %s" % window.size)
	var scroll: ScrollContainer = panel.find_child("ClipScroll", true, false)
	_check(scroll != null, "Daftar klip tidak bisa discroll")
	if scroll != null and window != null:
		scroll.scroll_vertical = 0
		for frame in range(3):
			await process_frame
		var window_rect := window.get_global_rect()
		# Titik awal di bagian bawah jendela: jelas berada di dalam daftar klip.
		var from := Vector2(window_rect.get_center().x,
			window_rect.position.y + window_rect.size.y * 0.72)
		_touch(15, from, true)
		for step in range(8):
			_drag(15, from + Vector2(0, -26 * (step + 1)))
			await process_frame
		_touch(15, from + Vector2(0, -208), false)
		for frame in range(3):
			await process_frame
		_check(scroll.scroll_vertical > 20,
			"Drag di tengah daftar tidak men-scroll (harus bisa dari mana saja)")
		scroll.scroll_vertical = 0
		for frame in range(2):
			await process_frame
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
