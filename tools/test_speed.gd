extends SceneTree

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
	var scene: PackedScene = load("res://src/game/main.tscn")
	var game := scene.instantiate() as Node3D
	root.add_child(game)
	var body: CharacterBody3D = game.get("_player")
	var visual: Node3D = game.get("_visual")
	var stick: Control = game.get("_joystick")
	var trail: Trail = game.get("_speed_aura")
	for frame in range(30):
		await physics_frame
	var start := body.position
	stick.set("direction", Vector2.RIGHT)
	for frame in range(20):
		await physics_frame
	var normal := Vector2(body.position.x - start.x, body.position.z - start.z).length()
	var normal_rate: float = visual.get("animation").speed_scale
	stick.set("direction", Vector2.ZERO)
	body.position = start
	for frame in range(5):
		await physics_frame
	game._toggle_speed()
	stick.set("direction", Vector2.RIGHT)
	for frame in range(20):
		await physics_frame
	var fast := Vector2(body.position.x - start.x, body.position.z - start.z).length()
	_check(fast > normal * 2.7 and fast < normal * 3.3, "Speed bukan 3x: %f/%f" % [fast, normal])
	_check(visual.get("animation").speed_scale < normal_rate * 0.4, "Animasi tidak diperlambat")
	_check(trail.strength > 0.5 and trail.ghosts.ghosts.size() == 3
		and trail.ghosts.emitted > 0, "Aura/budget salah")
	_check(trail.tint == Trail.COLORS["miku"], "Palet Miku bukan biru")
	_check(trail.environment.glow_enabled and trail.wash.visible, "Bloom/wash speed mati")
	stick.set("direction", Vector2.ZERO)
	await physics_frame
	for frame in range(50):
		await physics_frame
	_check(trail.strength == 0 and not trail.wash.visible, "Aura tidak memudar")
	_check(not trail.environment.glow_enabled, "Bloom tidak dipulihkan")
	game._toggle_speed()
	_check(not game.get("speed_boosted"), "Toggle normal gagal")
	game.queue_free()
	for frame in range(5):
		await process_frame
	print("[speed-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
