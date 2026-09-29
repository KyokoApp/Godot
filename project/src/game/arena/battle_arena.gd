extends Node3D
## Open traversable arena; ground and collision live in Island, not a floating disk.
const Shape = preload("res://src/game/arena/arena_shape.gd")
const SHADER = preload("res://src/game/arena/aurora.gdshader")
const SEGMENTS := 192


func _ready() -> void:
	name = "BattleArena"
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(SEGMENTS):
		var u := float(index) / SEGMENTS
		var v := float(index + 1) / SEGMENTS
		var a := _edge(u)
		var b := _edge(v)
		var high_a := a + Vector3.UP * (3.0 + sin(u * TAU * 7) * 0.5)
		var high_b := b + Vector3.UP * (3.0 + sin(v * TAU * 7) * 0.5)
		_vertex(mesh, a, Vector2(u, 0))
		_vertex(mesh, high_a, Vector2(u, 1))
		_vertex(mesh, b, Vector2(v, 0))
		_vertex(mesh, b, Vector2(v, 0))
		_vertex(mesh, high_a, Vector2(u, 1))
		_vertex(mesh, high_b, Vector2(v, 1))
	mesh.surface_end()
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = SHADER
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.visibility_range_end = 240
	visual.visibility_range_end_margin = 30
	add_child(visual)


func _edge(u: float) -> Vector3:
	var angle := u * TAU
	var p := Shape.CENTER + Vector2(cos(angle), sin(angle)) * Shape.radius_at(angle)
	return Vector3(p.x, Shape.HEIGHT + 0.03, p.y)


func _vertex(mesh: ImmediateMesh, point: Vector3, uv: Vector2) -> void:
	mesh.surface_set_uv(uv)
	mesh.surface_set_normal(Vector3.UP)
	mesh.surface_add_vertex(point)
