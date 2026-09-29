extends Control
## Joystick tetap di kiri bawah. Hanya jari pemilik yang boleh mengubah input.

const RADIUS := 86.0
const DEAD_ZONE := 0.15

var direction := Vector2.ZERO
var _finger := -1
var _offset := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(reset)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		reset()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.index == _finger and (not touch.pressed or touch.canceled):
			reset()
		elif touch.pressed and _finger == -1:
			var local := get_global_transform_with_canvas().affine_inverse() * touch.position
			if local.distance_to(_center()) <= RADIUS:
				_finger = touch.index
				_update_stick(local)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _finger:
			var local := get_global_transform_with_canvas().affine_inverse() * drag.position
			_update_stick(local)


func reset() -> void:
	_finger = -1
	_offset = Vector2.ZERO
	direction = Vector2.ZERO
	queue_redraw()


func _center() -> Vector2:
	return Vector2(140.0, size.y - 140.0)


func _update_stick(local: Vector2) -> void:
	_offset = (local - _center()).limit_length(RADIUS)
	var strength := _offset.length() / RADIUS
	if strength <= DEAD_ZONE:
		direction = Vector2.ZERO
	else:
		direction = _offset.normalized() * ((strength - DEAD_ZONE) / (1.0 - DEAD_ZONE))
	queue_redraw()


func _draw() -> void:
	draw_circle(_center(), RADIUS, Color(0.08, 0.10, 0.18, 0.4))
	draw_arc(_center(), RADIUS, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.6), 3.0, true)
	draw_circle(_center() + _offset, 34.0, Color(0.8, 0.72, 1.0, 0.85))
