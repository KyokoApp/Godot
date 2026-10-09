extends SceneTree
## Uji kecepatan + anti-meluncur:
##  1. boost menambah laju badan (bukan memperlambat animasi),
##  2. kecepatan badan selalu cocok dengan kecepatan klip × skala main,
##  3. aura cepat menyala saat boost lalu padam dan memulihkan bloom.

const Trail = preload("res://src/game/speed/speed_aura.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _run() -> void:
	var game := load("res://src/game/legacy_main.tscn").instantiate() as Node3D
	root.add_child(game)
	var player: CharacterBody3D = game.get("_player")
	for frame in range(60):
		await physics_frame
		if player != null and player.is_on_floor():
			break
	_check(player != null and player.is_on_floor(), "Pemain tidak mendarat")
	var visual: Node3D = game.get("_visual")
	var stick: Control = game.get("_joystick")
	var trail: Trail = game.get("_speed_aura")
	var normal: Dictionary = await _travel(player, visual, stick)
	_check(float(normal["distance"]) > 1.2, "Pemain tidak bergerak normal")
	stick.set("direction", Vector2.ZERO)
	for frame in range(20):
		await physics_frame
	# Kembali ke titik muncul utama di padang 100 m.
	player.spawn(Vector2(0.0, 7.0))
	for frame in range(10):
		await physics_frame
	game._toggle_speed()
	_check(player.boosted, "Toggle boost gagal")
	var fast: Dictionary = await _travel(player, visual, stick)
	var ratio := float(fast["distance"]) / maxf(float(normal["distance"]), 0.001)
	_check(ratio > 1.15 and ratio < 1.6, "Boost bukan 1,35×: %.2f" % ratio)
	_check(trail.strength > 0.4, "Aura cepat tidak aktif saat boost")
	# Efek ronde 18: pita jejak gerak (bukan afterimage) harus benar-benar
	# terisi saat boost, dan memudar lagi sesudahnya.
	_check(trail.trail.sample_count() >= 2, "Pita jejak tidak terisi saat boost")
	_check(trail.tint == Trail.TINT, "Warna aura bukan ungu mannequin")
	var glow_before: bool = trail.environment.glow_enabled
	_check(trail.environment.glow_enabled and trail.wash.visible, "Bloom/wash speed mati")
	stick.set("direction", Vector2.ZERO)
	for frame in range(60):
		await physics_frame
	_check(trail.strength == 0 and not trail.wash.visible, "Aura tidak memudar")
	# Glow senja sekarang menyala sejak awal, jadi yang dijamin adalah bloom
	# KEMBALI ke keadaan sebelum boost (bukan harus mati).
	_check(trail.environment.glow_enabled == glow_before, "Bloom tidak dipulihkan")
	game._toggle_speed()
	_check(not player.boosted, "Toggle normal gagal")
	game.queue_free()
	for frame in range(5):
		await process_frame
	print("[speed-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)


func _travel(player: CharacterBody3D, visual: Node3D, stick: Control) -> Dictionary:
	var start := player.position
	stick.set("direction", Vector2.RIGHT)
	var worst := 0.0
	var top := 0.0
	var frames := 44
	for frame in range(frames):
		await physics_frame
		if frame < frames - 12:
			continue # Lewati masa akselerasi, ukur bagian stabil saja.
		var gait: String = visual.get("gait")
		var natural: float = visual.call("natural_speed", gait)
		var scale: float = visual.get("animation").speed_scale
		top = maxf(top, player.move_speed)
		worst = maxf(worst, absf(player.move_speed - natural * scale))
	var tolerance := maxf(0.30, top * 0.15)
	_check(worst <= tolerance,
		"Kaki meluncur: selisih badan vs klip %.2f m/s (toleransi %.2f)" % [worst, tolerance])
	print("::notice::kecepatan %.2f m/s, selisih terburuk %.3f m/s" % [top, worst])
	var distance := Vector2(player.position.x - start.x,
		player.position.z - start.z).length()
	return {"distance": distance, "speed": top}
