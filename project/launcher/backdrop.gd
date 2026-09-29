extends Control
## Lanskap ringan tanpa aset luar; bar dan teks tetap kontras di atasnya.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var upper := Color("172440")
	var lower := Color("79658e")
	for band in range(64):
		var fraction := float(band) / 63.0
		draw_rect(Rect2(0, size.y * band / 64.0, size.x, size.y / 64.0 + 1),
			upper.lerp(lower, fraction))
	draw_circle(Vector2(size.x * 0.76, size.y * 0.34), size.y * 0.10, Color("d9c7bc"))
	_landscape(0.62, Color("4c4b70"), 0.0)
	_landscape(0.77, Color("343d5c"), 1.8)
	_landscape(0.91, Color("202e48"), 3.0)


func _landscape(height: float, color: Color, phase: float) -> void:
	var points := PackedVector2Array([Vector2(0, size.y)])
	for step in range(33):
		var x := float(step) / 32.0
		var y := height + sin(x * 9.0 + phase) * 0.06 + sin(x * 21.0 + phase) * 0.015
		points.append(Vector2(x * size.x, y * size.y))
	points.append(Vector2(size.x, size.y))
	draw_colored_polygon(points, color)
