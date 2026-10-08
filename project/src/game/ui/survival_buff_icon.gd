class_name SurvivalBuffIcon
extends Control
## Ikon vektor prosedural untuk kartu buff; tanpa glyph/asset tambahan.

var icon_kind := "flame"
var accent := Color("#ff8a54")
var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.43
	var pulse := 0.82 + 0.18 * sin(_time * 3.0)
	draw_circle(center, radius * 1.08, Color(accent.r, accent.g, accent.b, 0.075 * pulse))
	draw_arc(center, radius * 0.90, 0.0, TAU, 72,
		Color(accent.r, accent.g, accent.b, 0.26 + 0.14 * pulse), 1.2, true)
	draw_arc(center, radius * 0.73, _time * 0.16, _time * 0.16 + PI * 1.15, 48,
		Color(accent.r, accent.g, accent.b, 0.45), 1.0, true)
	match icon_kind:
		"flame", "brand":
			_draw_flame(center, radius * 0.66, accent)
			if icon_kind == "brand":
				draw_arc(center, radius * 0.48, -_time * 0.7, TAU - _time * 0.7,
					56, Color(1.0, 0.77, 0.44, 0.75), 1.0, true)
		"bolt":
			_draw_polygon(center, radius * 0.68, PackedVector2Array([
				Vector2(0.12, -1.0), Vector2(-0.50, 0.04), Vector2(-0.10, 0.04),
				Vector2(-0.28, 0.92), Vector2(0.56, -0.20), Vector2(0.12, -0.20),
			]), accent.lightened(0.22))
		"orbit":
			_draw_orbit(center, radius * 0.65, accent)
		"shield":
			_draw_polygon(center, radius * 0.66, PackedVector2Array([
				Vector2(0, -0.92), Vector2(0.75, -0.62), Vector2(0.63, 0.30),
				Vector2(0, 0.96), Vector2(-0.63, 0.30), Vector2(-0.75, -0.62),
			]), Color(accent.r, accent.g, accent.b, 0.38))
			draw_polyline(_scaled_points(center, radius * 0.66, PackedVector2Array([
			Vector2(0, -0.92), Vector2(0.75, -0.62), Vector2(0.63, 0.30),
			Vector2(0, 0.96), Vector2(-0.63, 0.30), Vector2(-0.75, -0.62),
			Vector2(0, -0.92),
		])), accent.lightened(0.3), 2.0, true)
		"heart":
			_draw_heart(center, radius * 0.67, accent)
		"star":
			_draw_star(center, radius * 0.68, accent, 8)
		"twin":
			_draw_flame(center + Vector2(-radius * 0.22, 0), radius * 0.44, accent)
			_draw_flame(center + Vector2(radius * 0.25, radius * 0.1), radius * 0.34,
				accent.lightened(0.28))
		"eye":
			_draw_eye(center, radius * 0.67, accent)
		"nova":
			_draw_star(center, radius * 0.64, accent, 12)
			for ray in 8:
				var angle := TAU * float(ray) / 8.0 + _time * 0.2
				draw_line(center + Vector2(cos(angle), sin(angle)) * radius * 0.5,
					center + Vector2(cos(angle), sin(angle)) * radius * 0.78,
					Color(accent.r, accent.g, accent.b, 0.7), 1.3, true)
		"vitality":
			_draw_polygon(center, radius * 0.64, PackedVector2Array([
				Vector2(-0.20, -0.86), Vector2(0.20, -0.86), Vector2(0.20, -0.20),
				Vector2(0.86, -0.20), Vector2(0.86, 0.20), Vector2(0.20, 0.20),
				Vector2(0.20, 0.86), Vector2(-0.20, 0.86), Vector2(-0.20, 0.20),
				Vector2(-0.86, 0.20), Vector2(-0.86, -0.20), Vector2(-0.20, -0.20),
			]), accent)
		"harvest":
			_draw_leaf(center, radius * 0.67, accent)
		"comet":
			var tail := PackedVector2Array([
				center + Vector2(-radius * 0.72, radius * 0.28),
				center + Vector2(-radius * 0.18, -radius * 0.06),
				center + Vector2(-radius * 0.55, radius * 0.68),
			])
			draw_polyline(tail, Color(accent.r, accent.g, accent.b, 0.8), 2.2, true)
			draw_circle(center + Vector2(radius * 0.18, -radius * 0.16), radius * 0.32,
				accent.lightened(0.28))
		"ice":
			_draw_ice(center, radius * 0.68, accent)
		"skull":
			_draw_skull(center, radius * 0.66, accent)
		_:
			_draw_star(center, radius * 0.65, accent, 8)


func _draw_ice(center: Vector2, scale: float, color: Color) -> void:
	for ray in 6:
		var angle := TAU * float(ray) / 6.0 + PI * 0.5
		var direction := Vector2(cos(angle), sin(angle))
		var end := center + direction * scale
		draw_line(center - direction * scale, end, color.lightened(0.2), 2.0, true)
		for branch_side in [-1.0, 1.0]:
			var branch := end - direction.rotated(branch_side * 0.72) * scale * 0.30
			draw_line(end - direction * scale * 0.36, branch, color, 1.4, true)


func _draw_skull(center: Vector2, scale: float, color: Color) -> void:
	draw_circle(center + Vector2(0, -scale * 0.12), scale * 0.49, color)
	draw_rect(Rect2(center + Vector2(-scale * 0.34, scale * 0.08),
		Vector2(scale * 0.68, scale * 0.48)), color)
	var shadow := Color(0.10, 0.08, 0.16, 1.0)
	draw_circle(center + Vector2(-scale * 0.20, -scale * 0.08), scale * 0.12, shadow)
	draw_circle(center + Vector2(scale * 0.20, -scale * 0.08), scale * 0.12, shadow)
	_draw_polygon(center, scale, PackedVector2Array([
		Vector2(0, 0.02), Vector2(-0.10, 0.25), Vector2(0.10, 0.25),
	]), shadow)
	for tooth in 3:
		var x := center.x + (float(tooth) - 1.0) * scale * 0.20
		draw_line(Vector2(x, center.y + scale * 0.30),
			Vector2(x, center.y + scale * 0.49), shadow, 1.4, true)


func _draw_flame(center: Vector2, scale: float, color: Color) -> void:
	_draw_polygon(center, scale, PackedVector2Array([
		Vector2(0.08, -1.0), Vector2(0.48, -0.38), Vector2(0.31, -0.08),
		Vector2(0.62, 0.18), Vector2(0.48, 0.72), Vector2(0.05, 0.98),
		Vector2(-0.46, 0.73), Vector2(-0.62, 0.26), Vector2(-0.34, -0.11),
		Vector2(-0.19, -0.48), Vector2(-0.05, -0.15),
	]), color)
	_draw_polygon(center + Vector2(0, scale * 0.25), scale * 0.35, PackedVector2Array([
		Vector2(0, -0.92), Vector2(0.62, -0.12), Vector2(0.46, 0.62),
		Vector2(0, 0.92), Vector2(-0.5, 0.58), Vector2(-0.58, -0.08),
	]), Color(1.0, 0.88, 0.54, 0.92))


func _draw_heart(center: Vector2, scale: float, color: Color) -> void:
	_draw_polygon(center, scale, PackedVector2Array([
		Vector2(0, 0.94), Vector2(-0.78, 0.18), Vector2(-0.82, -0.30),
		Vector2(-0.56, -0.72), Vector2(-0.16, -0.70), Vector2(0, -0.40),
		Vector2(0.20, -0.70), Vector2(0.60, -0.70), Vector2(0.84, -0.28),
		Vector2(0.75, 0.18),
	]), color)


func _draw_eye(center: Vector2, scale: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 25:
		var t := float(index) / 24.0
		var angle := PI * t
		points.append(center + Vector2(cos(angle) * scale, sin(angle) * scale * 0.56))
	for index in range(24, -1, -1):
		var t := float(index) / 24.0
		var angle := PI * t
		points.append(center + Vector2(cos(angle) * scale, -sin(angle) * scale * 0.56))
	draw_polyline(points, color, 2.0, true)
	draw_circle(center, scale * 0.24, color)
	draw_circle(center, scale * 0.11, Color(0.10, 0.10, 0.16, 1))


func _draw_leaf(center: Vector2, scale: float, color: Color) -> void:
	_draw_polygon(center, scale, PackedVector2Array([
		Vector2(-0.10, 0.98), Vector2(-0.82, 0.36), Vector2(-0.74, -0.38),
		Vector2(-0.04, -0.92), Vector2(0.70, -0.60), Vector2(0.84, 0.08),
		Vector2(0.42, 0.62),
	]), Color(color.r, color.g, color.b, 0.4))
	draw_line(center + Vector2(-scale * 0.52, scale * 0.54),
		center + Vector2(scale * 0.55, -scale * 0.64), color, 1.8, true)
	for index in 3:
		var t := float(index + 1) / 5.0
		draw_line(center + Vector2(-scale * 0.22 + t * scale * 0.65,
			scale * 0.10 - t * scale * 0.80),
			center + Vector2(-scale * 0.64 + t * scale * 0.65,
				scale * 0.18 - t * scale * 0.20), color, 1.1, true)


func _draw_orbit(center: Vector2, scale: float, color: Color) -> void:
	draw_arc(center, scale * 0.52, _time * 0.7, TAU + _time * 0.7,
		64, Color(color.r, color.g, color.b, 0.78), 1.6, true)
	draw_arc(center, scale * 0.75, -_time * 0.42, TAU - _time * 0.42,
		64, Color(color.r, color.g, color.b, 0.38), 1.0, true)
	for index in 3:
		var angle := TAU * float(index) / 3.0 + _time * 0.7
		draw_circle(center + Vector2(cos(angle), sin(angle)) * scale * 0.52,
			scale * 0.12, color.lightened(0.24))
	_draw_flame(center, scale * 0.35, Color(1.0, 0.84, 0.5, 0.95))


func _draw_star(center: Vector2, scale: float, color: Color, rays: int) -> void:
	var points := PackedVector2Array()
	for index in rays * 2:
		var radius := scale if index % 2 == 0 else scale * 0.28
		var angle := -PI * 0.5 + PI * float(index) / float(rays)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, color)


func _draw_polygon(center: Vector2, scale: float, points: PackedVector2Array,
		color: Color) -> void:
	draw_colored_polygon(_scaled_points(center, scale, points), color)


func _scaled_points(center: Vector2, scale: float,
		points: PackedVector2Array) -> PackedVector2Array:
	var transformed := PackedVector2Array()
	for point in points:
		transformed.append(center + point * scale)
	return transformed
