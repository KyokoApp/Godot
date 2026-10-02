extends Button
## Raw touch per finger: tidak bergantung pada emulasi satu pointer mouse GUI.

var rectangular := false
var glyph: Texture2D
## Label di dalam lingkaran (tanpa kotak): digambar di bawah glyph, atau di tengah
## kalau tombol tidak punya glyph.
var caption := ""
var compact := false
var cooldown_fraction := 0.0
## Warna cincin; alpha 0 = putih standar.
var accent := Color(1, 1, 1, 0)
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
	if rectangular:
		return Rect2(Vector2.ZERO, size).has_point(local)
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
	if rectangular:
		draw_style_box(get_theme_stylebox("panel", "Panel"), Rect2(Vector2.ZERO, size))
		return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 3.0
	var held := _finger != -1
	# Cakram berisi + cincin aksen: bulat, bukan kotak, dan tetap terbaca di atas
	# rumput gelap tanpa border tebal.
	draw_circle(center, radius, Color(0.06, 0.05, 0.11, 0.42 if held else 0.30))
	draw_circle(center, radius * 0.86, Color(0.13, 0.10, 0.22, 0.5 if held else 0.34))
	var ring := accent if accent.a > 0.0 else Color(1, 1, 1, 0.34)
	draw_arc(center, radius, 0, TAU, 80, Color(ring.r, ring.g, ring.b, 0.95 if held else ring.a),
		2, true)
	var caption_size := maxi(12, int(minf(size.x, size.y) * 0.16))
	var has_glyph := glyph != null
	if has_glyph:
		var factor := 0.60 if compact else 0.56
		if caption != "":
			factor = 0.46
		var extent := size * factor * (0.94 if held else 1.0)
		var tint := Color(1, 1, 1, 0.5 if cooldown_fraction > 0 else 1.0)
		var offset := Vector2(0, -size.y * 0.05) if caption != "" else Vector2.ZERO
		draw_texture_rect(glyph, Rect2(center - extent * 0.5 + offset, extent), false, tint)
	if caption != "":
		var font := ThemeDB.fallback_font
		var baseline := Vector2(0, size.y * (0.86 if has_glyph else 0.62))
		draw_string(font, baseline, caption, HORIZONTAL_ALIGNMENT_CENTER,
			size.x, caption_size, Color(1, 1, 1, 0.94 if held else 0.86))
	if cooldown_fraction > 0.001:
		draw_arc(center, radius - 2, -PI * 0.5,
			-PI * 0.5 + TAU * cooldown_fraction, 80, Color.WHITE, 3, true)
