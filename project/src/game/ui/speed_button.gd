extends "res://src/game/ui/rune_button.gd"

var boosted := false


func _draw() -> void:
	super._draw()
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0, size.y - 5), "×3" if boosted else "×1",
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color.WHITE)
	if boosted:
		draw_arc(size * 0.5, size.x * 0.5 - 3, 0, TAU, 64, Color.WHITE, 2, true)
