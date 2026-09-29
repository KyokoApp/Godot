extends SceneTree

const Shape = preload("res://src/game/arena/arena_Shape.gd")
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
	var edge := Shape.CENTER + Vector2(Shape.radius_at(0), 0)
	stick.set("direction", Vector2.RIGHT)
	body.position = Vector3(edge.x + 0.1, Shape.HEIGHT + 1, edge.y)
	game._update_arena_state()
	game._toggle_speed()
	_check(game.speed_boosted and game._speed_button.visible, "Speed hilang di luar batas")
	body.position = Vector3(edge.x - 0.1, Shape.HEIGHT + 1, edge.y)
	game._update_arena_state()
	_check(not game.speed_boosted, "Boost tetap aktif tepat sesudah batas")
	body.position.x -= 2
	await physics_frame
	await physics_frame
	_check(game.inside_arena and not game.speed_boosted, "Boost tidak dibatalkan saat masuk")
	_check(not game._speed_button.visible and trail.strength == 0, "Speed/VFX bocor ke arena")
	_check(Vector2(body.velocity.x, body.velocity.z).length() <= 5.01, "Arena lebih dari 5m/s")
	game._toggle_speed()
	_check(not game.speed_boosted, "Boost bisa aktif di arena")
	game._toggle_graphics()
	game._toggle_graphics()
	_check(not game._speed_button.visible, "Drawer memunculkan speed di arena")
	body.position = Vector3(edge.x + 2, Shape.HEIGHT + 1, edge.y)
	game._update_arena_state()
	_check(game._speed_button.visible and not game.speed_boosted,
		"Speed tidak kembali tersedia/aktif otomatis saat keluar")
	game._toggle_speed()
	_check(game.speed_boosted, "Speed tidak bisa dinyalakan setelah keluar")
	game._toggle_graphics()
	_check(not game._speed_button.visible, "Speed menimpa drawer grafik")
	game._toggle_graphics()
	game.queue_free()
	for frame in range(5):
		await process_frame
	print("[speed-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
