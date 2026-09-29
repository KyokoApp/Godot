extends "res://src/game/ui/rune_button.gd"
## Original party-card design: portrait, active accent, slot number. No fake HP bar.

var portrait: Texture2D
var character_name := ""
var slot := "01"
var selected := false
var accent := Color("98eee3")


func contains_point(point: Vector2) -> bool:
	return get_global_rect().has_point(point)


func _draw() -> void:
	var held := _finger != -1
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.07, 0.09, 0.16, 0.94 if held else 0.82)
	box.border_color = accent if selected else Color(0.68, 0.72, 0.82, 0.30)
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	box.shadow_color = Color(0.01, 0.02, 0.04, 0.25)
	box.shadow_size = 3
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	draw_line(Vector2(3, 19), Vector2(3, size.y - 19),
		accent if selected else Color(0.7, 0.75, 0.8, 0.25), 3, true)
	var center := Vector2(38, size.y * 0.5)
	draw_circle(center, 29, Color(0.12, 0.16, 0.24))
	if portrait != null:
		draw_texture_rect(portrait, Rect2(center - Vector2(27, 27), Vector2(54, 54)), false)
	draw_arc(center, 29, 0, TAU, 64, accent if selected else Color("697088"), 1, true)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(76, 30), character_name, HORIZONTAL_ALIGNMENT_LEFT,
		-1, 19, Color("f0f0fc"))
	draw_string(font, Vector2(77, 49), "AKTIF" if selected else "GANTI",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, accent if selected else Color("a8b0c6"))
	draw_string(font, Vector2(size.x - 21, 15), slot, HORIZONTAL_ALIGNMENT_LEFT,
		-1, 10, Color(0.8, 0.85, 0.96, 0.55))
