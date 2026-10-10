extends Button
## A luminous, circular action button inspired by mobile action-game controls.

var flying_mode := false
var caption := "SWITCH"
var _held := false
var _hovered := false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	text = ""
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button_down.connect(_set_held.bind(true))
	button_up.connect(_set_held.bind(false))
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))


func set_flying(value: bool) -> void:
	flying_mode = value
	queue_redraw()


func _set_held(value: bool) -> void:
	_held = value
	queue_redraw()


func _set_hovered(value: bool) -> void:
	_hovered = value
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 3.0
	var accent := Color("5dbbff") if flying_mode else Color("8fd8ff")
	var alpha := 0.77 if _held else (0.62 if _hovered else 0.50)

	# Soft, dark glass disk and thin rings echo a Genshin-style action button.
	draw_circle(center, radius, Color(0.025, 0.05, 0.10, alpha))
	draw_circle(center + Vector2(0.0, -radius * 0.20), radius * 0.73,
		Color(0.46, 0.72, 1.0, 0.055 if not _held else 0.09))
	draw_arc(center, radius - 2.0, 0.0, TAU, 96,
		Color(accent.r, accent.g, accent.b, 0.92 if _held else 0.72), 2.0, true)
	draw_arc(center, radius - 7.0, 0.0, TAU, 96,
		Color(0.88, 0.94, 1.0, 0.14), 1.0, true)

	# Two curved arrows wrap around a softly glowing, rippled orb.
	var arrow_radius := radius * 0.49
	draw_arc(center + Vector2(0.0, -3.0), arrow_radius, -2.92, -0.18, 40,
		Color(accent.r, accent.g, accent.b, 0.82), 2.0, true)
	draw_arc(center + Vector2(0.0, -3.0), arrow_radius, 0.22, 2.96, 40,
		Color(accent.r, accent.g, accent.b, 0.58), 2.0, true)
	var arrow := center + Vector2(cos(-0.18), sin(-0.18)) * arrow_radius
	draw_line(arrow, arrow + Vector2(-7.0, -2.0), accent, 2.0, true)
	draw_line(arrow, arrow + Vector2(-2.0, 6.0), accent, 2.0, true)
	var return_arrow := center + Vector2(cos(2.96), sin(2.96)) * arrow_radius
	draw_line(return_arrow, return_arrow + Vector2(7.0, 2.0), accent, 2.0, true)
	draw_line(return_arrow, return_arrow + Vector2(2.0, -6.0), accent, 2.0, true)

	var orb_center := center + Vector2(0.0, -4.0)
	draw_circle(orb_center, radius * 0.235, Color(0.07, 0.43, 0.90, 0.52))
	draw_circle(orb_center, radius * 0.17, Color(0.15, 0.68, 1.0, 0.90))
	draw_arc(orb_center, radius * 0.17, -2.85, 0.10, 40,
		Color(0.80, 0.95, 1.0, 0.88), 1.4, true)
	var wave := PackedVector2Array()
	for index in range(19):
		var x := float(index) / 18.0 * radius * 0.27 - radius * 0.135
		var y := sin(float(index) / 18.0 * TAU) * radius * 0.035
		wave.append(orb_center + Vector2(x, y))
	draw_polyline(wave, Color(0.86, 0.97, 1.0, 0.9), 1.35, true)

	var font := ThemeDB.fallback_font
	var label_size := maxi(9, int(radius * 0.25))
	draw_string(font, Vector2(0.0, center.y + radius * 0.72), caption,
		HORIZONTAL_ALIGNMENT_CENTER, size.x, label_size,
		Color(0.93, 0.98, 1.0, 0.94 if _held else 0.82))
