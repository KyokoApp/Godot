extends SceneTree
## Rekam alur animasi lari -> lompat -> lari, frame demi frame.
##
## Tujuannya bukan sekadar lulus/gagal: baris hanya dicetak saat klip, mode, atau
## status busy BERUBAH, jadi terlihat persis di frame mana animasi berhenti,
## mundur ke pose mendarat, atau terlambat menyambung lagi.

const Character = preload("res://src/game/mannequin.gd")

var _failures := 0
var _previous := ""
var _lines: PackedStringArray = PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _sample(frame: int, player: CharacterBody3D, visual: Character, tag: String) -> void:
	var busy := visual.is_busy()
	var state := "%s|%s|%s" % [visual.clip, visual.mode, busy]
	if state == _previous:
		return
	_previous = state
	_lines.append("f%03d %-16s mode=%-2d busy=%-5s gait=%-14s v=%.2f y=%.2f %s" % [
		frame, visual.clip, visual.mode, busy, visual.gait,
		float(player.get("move_speed")), player.position.y, tag])


func _run() -> void:
	var game := load("res://src/game/main.tscn").instantiate() as Node3D
	root.add_child(game)
	var player: CharacterBody3D = game.get("_player")
	var visual: Character = game.get("_visual")
	var stick: Control = game.get("_joystick")
	for frame in range(60):
		await physics_frame
		if player.is_on_floor():
			break
	_check(player.is_on_floor(), "Pemain tidak mendarat di awal")
	# Lari dulu sampai kecepatan penuh.
	stick.set("direction", Vector2.RIGHT)
	for frame in range(45):
		await physics_frame
	var running := float(player.get("move_speed"))
	_check(running > 3.0, "Pemain tidak berlari sebelum lompat: %.2f m/s" % running)
	var takeoff_y := player.position.y
	_sample(0, player, visual, "SEBELUM LOMPAT (lari penuh)")
	# Lompat sambil terus berlari.
	player.request_jump()
	var landed_frame := -1
	var landing_clip := ""
	var landing_busy := false
	var loop_frames := 0
	for frame in range(1, 121):
		await physics_frame
		_sample(frame, player, visual, "")
		if visual.clip == "Jump_Loop":
			loop_frames += 1
		if landed_frame < 0 and frame > 4 and player.position.y <= takeoff_y + 0.02:
			landed_frame = frame
			landing_clip = visual.clip
			landing_busy = visual.is_busy()
			_sample(frame, player, visual, "<-- MENDARAT")
	for frame in range(10):
		await physics_frame
		_sample(120 + frame, player, visual, "setelah mendarat")
	stick.set("direction", Vector2.ZERO)
	for frame in range(40):
		await physics_frame
		_sample(160 + frame, player, visual, "berhenti")
	_check(landed_frame > 0, "Pemain tidak pernah mendarat")
	_check(loop_frames >= 10, "Klip melayang cuma %d frame" % loop_frames)
	_check(landing_clip != "Jump_Land",
		"Mendarat sambil lari masih memutar Jump_Land (pose jongkok)")
	_check(not landing_busy, "Animasi terkunci (busy) saat mendarat sambil lari")
	_check(str(visual.clip).ends_with("_Loop") or visual.clip == "Idle_Loop",
		"Setelah mendarat tidak langsung menyambung ke gait: " + str(visual.clip))
	for line in _lines:
		print("[jump-trace] ", line)
	print("[jump-trace] lompat %d frame, melayang %d frame, mendarat di frame %d dengan klip %s" % [
		landed_frame, loop_frames, landed_frame, landing_clip])
	print("[jump-trace] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
