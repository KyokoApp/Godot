extends SceneTree
## Tes input sentuh dan gerak tanpa GPU; tampilan tetap harus diuji di HP.

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _touch(stick: Control, index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = stick.get_global_transform_with_canvas() * point
	event.pressed = pressed
	stick._input(event)


func _drag(stick: Control, index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = stick.get_global_transform_with_canvas() * point
	stick._input(event)


func _run() -> void:
	var scene: PackedScene = load("res://src/game/main.tscn")
	var game: Node3D = scene.instantiate()
	root.add_child(game)
	await process_frame
	var stick: Control = game.get("_joystick")
	var player: CharacterBody3D = game.get("_player")
	var center := Vector2(140.0, stick.size.y - 140.0)
	_touch(stick, 0, center, true)
	_drag(stick, 0, center + Vector2(2, 0))
	_check(stick.get("direction") == Vector2.ZERO, "Dead zone gagal")
	_drag(stick, 0, center + Vector2(200, 0))
	var direction: Vector2 = stick.get("direction")
	_check(direction.is_equal_approx(Vector2.RIGHT), "Clamp joystick gagal")
	_touch(stick, 1, center, true)
	_drag(stick, 1, center + Vector2(-100, 0))
	_touch(stick, 1, center, false)
	_check(stick.get("direction") == direction, "Jari kedua mengambil joystick")
	var start := player.position
	for frame in range(30):
		await physics_frame
	_check(player.position.x > start.x + 1.0, "Pemain tidak bergerak ke kanan")
	_touch(stick, 0, center + Vector2(200, 0), false)
	_check(stick.get("direction") == Vector2.ZERO, "Lepas di luar joystick tidak reset")
	for frame in range(3):
		await physics_frame
	_check(absf(player.velocity.x) < 0.001, "Pemain tidak berhenti")
	_touch(stick, 2, center, true)
	_drag(stick, 2, center + Vector2(0, -86))
	start = player.position
	for frame in range(30):
		await physics_frame
	_check(player.position.z < start.z - 1.0, "Arah atas joystick salah")
	stick.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(stick.get("direction") == Vector2.ZERO, "Input tersangkut saat kehilangan fokus")
	_check(absf(player.position.y - 0.9) < 0.1, "Kapsul tidak berpijak di tanah")
	print("[movement-test] gagal: ", _failures)
	quit(0 if _failures == 0 else 1)
