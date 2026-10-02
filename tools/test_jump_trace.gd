extends SceneTree
## Rekam alur animasi lari -> lompat -> lari, frame demi frame.
##
## Tujuannya bukan sekadar lulus/gagal: baris hanya dicetak saat klip, mode, atau
## status busy BERUBAH, jadi terlihat persis di frame mana animasi berhenti,
## mundur ke pose mendarat, atau terlambat menyambung lagi.
##
## Analognya SENGAJA dilepas tepat saat menekan LOMPAT, karena itu yang terjadi
## di HP: jempol pindah dari analog ke tombol. Dulu di situ badan kehilangan laju
## di udara, mendarat pelan, lalu memutar pose jongkok sebelum jalan lagi.

const Character = preload("res://src/game/character/aurelia_visual.gd")

var _failures := 0
var _frame := 0
var _previous := ""
var _lines: PackedStringArray = PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _step() -> void:
	await physics_frame
	_frame += 1


func _sample(player: CharacterBody3D, visual: Character, tag: String,
		force := false) -> void:
	var busy := visual.is_busy()
	var state := "%s|%s|%s" % [visual.clip, visual.mode, busy]
	if state == _previous and not force:
		return
	_previous = state
	_lines.append("f%03d %-16s mode=%-2d busy=%-5s gait=%-14s v=%.2f y=%.2f %s" % [
		_frame, visual.clip, visual.mode, busy, visual.gait,
		float(player.get("move_speed")), player.position.y, tag])


func _run() -> void:
	var game := load("res://src/game/main.tscn").instantiate() as Node3D
	root.add_child(game)
	var player: CharacterBody3D = game.get("_player")
	var visual: Character = game.get("_visual")
	var stick: Control = game.get("_joystick")
	for frame in range(60):
		await _step()
		if player.is_on_floor():
			break
	_check(player.is_on_floor(), "Pemain tidak mendarat di awal")
	# Lari dulu sampai kecepatan penuh.
	stick.set("direction", Vector2.RIGHT)
	for frame in range(45):
		await _step()
	var running := float(player.get("move_speed"))
	_check(running > 3.0, "Pemain tidak berlari sebelum lompat: %.2f m/s" % running)
	# Lompat sambil berlari, lalu lepas analog seperti jempol di HP.
	_sample(player, visual, "SEBELUM LOMPAT (lari penuh)", true)
	var takeoff_speed := float(player.get("move_speed"))
	var takeoff_at := player.global_position
	player.request_jump()
	stick.set("direction", Vector2.ZERO)
	var landed_frame := -1
	var landing_clip := ""
	var landing_busy := false
	var land_speed := 0.0
	var air_speed_min := takeoff_speed
	var air_distance := 0.0
	var loop_frames := 0
	var flew := false
	for frame in range(1, 121):
		await _step()
		var speed := float(player.get("move_speed"))
		var tag := ""
		if not player.is_on_floor():
			flew = true
			air_speed_min = minf(air_speed_min, speed)
		elif flew and landed_frame < 0:
			landed_frame = _frame
			landing_clip = str(visual.clip)
			landing_busy = visual.is_busy()
			land_speed = speed
			var traveled := Vector2(player.global_position.x - takeoff_at.x,
				player.global_position.z - takeoff_at.z)
			air_distance = traveled.length()
			tag = "<-- MENDARAT %.2f m/s (terbang %.2f m)" % [speed, air_distance]
		_sample(player, visual, tag, landed_frame == _frame)
		if visual.clip == "Jump_Loop":
			loop_frames += 1
	# Tanpa input setelah mendarat: kaki melambat lewat klip gait, bukan langsung
	# berpose Idle sambil badan meluncur.
	var glide_clips: PackedStringArray = PackedStringArray()
	for frame in range(20):
		await _step()
		_sample(player, visual, "meluncur berhenti")
		if not glide_clips.has(str(visual.clip)):
			glide_clips.append(str(visual.clip))
	# Pegang analog lagi: lari harus langsung lanjut tanpa klip mendarat.
	stick.set("direction", Vector2.RIGHT)
	var resumed := ""
	for frame in range(25):
		await _step()
		_sample(player, visual, "pegang analog lagi")
		if player.is_on_floor() and float(player.get("move_speed")) > 3.0:
			resumed = str(visual.clip)
			break
	stick.set("direction", Vector2.ZERO)
	for frame in range(40):
		await _step()
		_sample(player, visual, "berhenti")
	_check(landed_frame > 0, "Pemain tidak pernah mendarat")
	_check(loop_frames >= 10, "Klip melayang cuma %d frame" % loop_frames)
	_check(landing_clip != "Jump_Land",
		"Mendarat sambil lari masih memutar Jump_Land (pose jongkok)")
	_check(not landing_busy, "Animasi terkunci (busy) saat mendarat sambil lari")
	_check(landing_clip.ends_with("_Loop") or landing_clip == "Idle_Loop",
		"Setelah mendarat tidak langsung menyambung ke gait: " + landing_clip)
	_check(air_speed_min > 2.0,
		"Laju lari dibuang di udara: tersisa %.2f m/s" % air_speed_min)
	_check(land_speed > 2.0,
		"Mendarat cuma %.2f m/s (badan hampir berhenti)" % land_speed)
	_check(air_distance > 2.0, "Jarak terbang cuma %.2f m" % air_distance)
	_check(not glide_clips.has("Jump_Land"),
		"Klip mendarat muncul saat meluncur: " + ", ".join(glide_clips))
	_check(resumed != "" and resumed != "Idle_Loop" and resumed.ends_with("_Loop"),
		"Lari tidak lanjut setelah mendarat: " + resumed)
	for line in _lines:
		print("[jump-trace] ", line)
	var upto := "lompat %.2f m/s -> melayang %d frame (min %.2f m/s, jauh %.2f m)"
	var after := " -> mendarat f%d %.2f m/s klip %s -> pegang analog lagi jadi %s"
	var summary := [takeoff_speed, loop_frames, air_speed_min, air_distance,
		landed_frame, land_speed, landing_clip, resumed]
	print("[jump-trace] ", (upto + after) % summary)
	print("[jump-trace] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
