extends RefCounted
## One shared low-poly mesh: asymmetric sole + five tapered, genuinely 3D tongues.


static func create() -> ArrayMesh:
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline: Array[Vector2] = [Vector2(-0.036, 0.12), Vector2(0.035, 0.12),
		Vector2(0.044, 0.03), Vector2(0.064, -0.07), Vector2(0.045, -0.14),
		Vector2(0.004, -0.155), Vector2(-0.045, -0.13), Vector2(-0.058, -0.065),
		Vector2(-0.033, 0.04)]
	for index in range(outline.size()):
		var a := Vector3(outline[index].x, 0.006, outline[index].y)
		var next := outline[(index + 1) % outline.size()]
		var b := Vector3(next.x, 0.006, next.y)
		_triangle(builder, Vector3(0, 0.006, 0), b, a, 0, 1, 0)
		_triangle(builder, a, b, a - Vector3.UP * 0.006, 0, 1, 0)
		_triangle(builder, b, b - Vector3.UP * 0.006,
			a - Vector3.UP * 0.006, 0, 1, 0)
	var centers := [Vector3(0, 0, -0.095), Vector3(-0.028, 0, -0.045),
		Vector3(0.028, 0, -0.015), Vector3(0, 0, 0.045), Vector3(0, 0, 0.09)]
	for index in range(centers.size()):
		var center: Vector3 = centers[index]
		var height := 0.24 - index * 0.022
		for row in range(4):
			for side in range(7):
				var a := _point(center, row / 4.0, side, height)
				var b := _point(center, row / 4.0, side + 1, height)
				var c := _point(center, (row + 1) / 4.0, side, height)
				var d := _point(center, (row + 1) / 4.0, side + 1, height)
				_triangle(builder, a, b, c, 1, height, index * 0.19)
				_triangle(builder, b, d, c, 1, height, index * 0.19)
	builder.generate_normals()
	return builder.commit()


static func _point(center: Vector3, fraction: float, side: int, height: float) -> Vector3:
	var radius := 0.029 * (1.0 - fraction) * (0.6 + sin(fraction * PI) * 0.7)
	var angle := side / 7.0 * TAU
	return center + Vector3(cos(angle) * radius, fraction * height, sin(angle) * radius)


static func _triangle(builder: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		role: float, height: float, seed: float) -> void:
	for point: Vector3 in [a, b, c]:
		builder.set_color(Color(point.y / height if role > 0 else 0, role, seed))
		builder.set_uv(Vector2((point.x + 0.08) / 0.16, point.y / height))
		builder.add_vertex(point)
