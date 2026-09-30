extends Node3D
## Smoke beyond the aurora only; no white sky dome or global environment changes.

const Shape = preload("res://src/game/arena/arena_shape.gd")
const SHADER = preload("res://src/game/arena/arena_fog.gdshader")
const WALL_OFFSET := 12.0 # Beyond the 8m camera arm and the aurora ring.
const FULL_INSIDE := -5.0

var player: Node3D
var fog_amount := 0.0
var _materials: Array[ShaderMaterial] = []
var _shells: Array[MeshInstance3D] = []


func _ready() -> void:
	name = "ArenaFog"
	for index in range(2):
		_add_wall(index)


func _add_wall(index: int) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for step in range(192):
		var u := float(step) / 192.0
		var v := float(step + 1) / 192.0
		var a := _wall_point(u, index)
		var b := _wall_point(v, index)
		_wall_vertex(mesh, a, Vector2(u, 0))
		_wall_vertex(mesh, a + Vector3.UP * 70.0, Vector2(u, 1))
		_wall_vertex(mesh, b, Vector2(v, 0))
		_wall_vertex(mesh, b, Vector2(v, 0))
		_wall_vertex(mesh, a + Vector3.UP * 70.0, Vector2(u, 1))
		_wall_vertex(mesh, b + Vector3.UP * 70.0, Vector2(v, 1))
	mesh.surface_end()
	var shell := MeshInstance3D.new()
	shell.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.render_priority = -4 + index
	shell.material_override = material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	shell.visible = false
	add_child(shell)
	_materials.append(material)
	_shells.append(shell)


func _wall_point(u: float, index: int) -> Vector3:
	var angle := u * TAU
	var radius := Shape.radius_at(angle) + WALL_OFFSET + index * 3.0
	var point := Shape.CENTER + Vector2(cos(angle), sin(angle)) * radius
	return Vector3(point.x, Shape.HEIGHT - 8.0, point.y)


func _wall_vertex(mesh: ImmediateMesh, position: Vector3, uv: Vector2) -> void:
	mesh.surface_set_uv(uv)
	mesh.surface_set_normal(Vector3.UP)
	mesh.surface_add_vertex(position)


func _process(delta: float) -> void:
	if is_instance_valid(player):
		update_for_position(player.global_position, delta)


func update_for_position(position: Vector3, delta: float) -> void:
	var distance := Shape.distance_to(position.x, position.z)
	var target := 1.0 - smoothstep(FULL_INSIDE, 0.0, distance)
	fog_amount = lerpf(fog_amount, target, 1.0 - exp(-3.0 * delta))
	# Spatial fade already reaches zero at the boundary. Never carry fog outside.
	fog_amount = minf(fog_amount, target)
	if fog_amount < 0.002 and target == 0:
		fog_amount = 0.0
	for index in range(_shells.size()):
		_shells[index].visible = fog_amount > 0.0
		_materials[index].set_shader_parameter("fog_amount", fog_amount)
