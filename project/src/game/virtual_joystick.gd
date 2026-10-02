extends Control
## Joystick mengambang di separuh kiri layar, hanya tampak saat disentuh.
## Hanya jari pemilik yang boleh mengubah input.

const RADIUS := 86.0
const DEAD_ZONE := 0.15

var input_exclusion: Control
## Semua kontrol HUD yang tidak boleh memulai analog (tombol bulat, panel, laci).
var input_exclusions: Array[Control] = []
var input_enabled := true
var direction := Vector2.ZERO
var _finger := -1
var _offset := Vector2.ZERO
var _origin := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(reset)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		reset()


func _input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.index == _finger and (not touch.pressed or touch.canceled):
			reset()
		elif touch.pressed and _finger == -1:
			if _blocked(touch.position):
				return
			var local := get_global_transform_with_canvas().affine_inverse() * touch.position
			if Rect2(Vector2.ZERO, Vector2(size.x * 0.5, size.y)).has_point(local):
				_origin = local
				_finger = touch.index
				_update_stick(local)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _finger:
			var local := get_global_transform_with_canvas().affine_inverse() * drag.position
			_update_stick(local)


func _blocked(point: Vector2) -> bool:
	# Tombol HUD juga mendengar sentuhan langsung, jadi analog harus mengalah:
	# menekan tombol tidak boleh sekaligus mulai berjalan.
	for control in input_exclusions:
		if not is_instance_valid(control) or not control.is_visible_in_tree():
			continue
		if control.has_method("contains_point"):
			if bool(control.call("contains_point", point)):
				return true
		elif control.get_global_rect().has_point(point):
			return true
	if not is_instance_valid(input_exclusion) or not input_exclusion.is_visible_in_tree():
		return false
	if input_exclusion.has_method("contains_point"):
		return bool(input_exclusion.call("contains_point", point))
	return input_exclusion.get_global_rect().has_point(point)


func reset() -> void:
	_finger = -1
	_offset = Vector2.ZERO
	direction = Vector2.ZERO
	queue_redraw()


func _center() -> Vector2:
	return _origin


func _update_stick(local: Vector2) -> void:
	_offset = (local - _center()).limit_length(RADIUS)
	var strength := _offset.length() / RADIUS
	if strength <= DEAD_ZONE:
		direction = Vector2.ZERO
	else:
		direction = _offset.normalized() * ((strength - DEAD_ZONE) / (1.0 - DEAD_ZONE))
	queue_redraw()


func _draw() -> void:
	if _finger == -1:
		return
	draw_circle(_center(), RADIUS, Color(0.08, 0.10, 0.18, 0.16))
	draw_arc(_center(), RADIUS, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, 0.28), 3.0, true)
	draw_circle(_center() + _offset, 34.0, Color(1, 1, 1, 0.38))
