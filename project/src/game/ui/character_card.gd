extends "res://src/game/ui/rune_button.gd"
## Transparent party row: left name, right portrait, white selection only.

var portrait: Texture2D
var character_name := ""
var selected := false


func contains_point(point: Vector2) -> bool:
	return get_global_rect().has_point(point)


func _draw() -> void:
	var center := Vector2(size.x - 34, size.y * 0.5)
	if portrait != null:
		draw_texture_rect(portrait, Rect2(center - Vector2(27, 27), Vector2(54, 54)), false)
	var white := Color(1, 1, 1, 1.0 if selected or _finger != -1 else 0.7)
	if selected:
		draw_arc(center, 29, 0, TAU, 64, white, 1, true)
		draw_circle(Vector2(size.x - 2, size.y * 0.5), 2, white)
	var font := ThemeDB.fallback_font
	var label_position := Vector2(0, size.y * 0.5 + 6)
	var width := size.x - 78
	# A subtle neutral text shadow, no panel or colored border covering the world.
	draw_string(font, label_position + Vector2(1, 1), character_name,
		HORIZONTAL_ALIGNMENT_RIGHT, width, 19, Color(0, 0, 0, 0.45))
	draw_string(font, label_position, character_name,
		HORIZONTAL_ALIGNMENT_RIGHT, width, 19, white)
