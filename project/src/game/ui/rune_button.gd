extends Button
## Raw touch per finger: tidak bergantung pada emulasi satu pointer mouse GUI.

var glyph: Texture2D
var compact := false
var cooldown_fraction := 0.0
var _finger := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	get_viewport().size_changed.connect(reset_touch)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		reset_touch()
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		reset_touch()


func reset_touch() -> void:
	_finger = -1
	queue_redraw()


func contains_point(point: Vector2) -> bool:
	var local := get_global_transform_with_canvas().affine_inverse() * point
	return local.distance_to(size * 0.5) <= minf(size.x, size.y) * 0.5


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or disabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.index == _finger and (not touch.pressed or touch.canceled):
			reset_touch()
		elif touch.pressed and not touch.canceled and _finger == -1:
			if contains_point(touch.position):
				_finger = touch.index
				queue_redraw()
				pressed.emit()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT:
			if not mouse.pressed and _finger == -2:
				reset_touch()
			elif mouse.pressed and _finger == -1 and contains_point(mouse.position):
				_finger = -2
				queue_redraw()
				pressed.emit()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 3.0
	var held := _finger != -1
	draw_circle(center + Vector2(0, 3), radius, Color(0.03, 0.02, 0.08, 0.24))
	draw_circle(center, radius, Color(0.10, 0.07, 0.20, 0.64 if compact else 0.80))
	draw_circle(center, radius - 5, Color(0.43, 0.29, 0.68, 0.44 if held else 0.19))
	draw_arc(center, radius, 0, TAU, 80, Color(0.78, 0.70, 1, 0.85), 1.5, true)
	draw_arc(center, radius - 5, 0, TAU, 80, Color(0.70, 0.59, 1, 0.26), 1, true)
	if not compact:
		for index in range(4):
			var angle := PI * 0.25 + index * PI * 0.5
			var tip := center + Vector2.from_angle(angle) * (radius - 9)
			draw_circle(tip, 1.5, Color(0.82, 0.77, 1, 0.9))
	if glyph != null:
		var extent := size * (0.67 if compact else 0.65) * (0.94 if held else 1.0)
		var tint := Color(1, 1, 1, 0.5 if cooldown_fraction > 0 else 1.0)
		draw_texture_rect(glyph, Rect2(center - extent * 0.5, extent), false, tint)
	if cooldown_fraction > 0.001:
		draw_arc(center, radius - 2, -PI * 0.5,
			-PI * 0.5 + TAU * cooldown_fraction, 80, Color(0.71, 0.88, 1), 3, true)
