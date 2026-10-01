extends Node3D
## Sparse crossed 2D cards (4 tris/clump), blended with existing near grass.

const TILE := 32.0
const GRID := 12
const RADIUS := 3
const MAX_TILES := 49
const MAX_TRIANGLES := MAX_TILES * GRID * GRID * 4
const SHADER = preload("res://src/game/world/grass_distance.gdshader")

var field: Node3D
var tiles: Dictionary[Vector2i, MultiMeshInstance3D] = {}
var _center := Vector2i(9999, 9999)
var _pending: Array[Vector2i] = []
var _mesh: ArrayMesh
var _material: ShaderMaterial


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("blade_mask", preload("res://assets/nature/grass_cards.png"))
	_mesh = _make_mesh()


func update_center(point: Vector3) -> void:
	_material.set_shader_parameter("player_position", point)
	var center := Vector2i(floori(point.x / TILE), floori(point.z / TILE))
	if center != _center:
		_center = center
		_pending.clear()
		for key in tiles.keys():
			if maxi(absi(key.x - center.x), absi(key.y - center.y)) > RADIUS:
				tiles[key].queue_free()
				tiles.erase(key)
		for z in range(center.y - RADIUS, center.y + RADIUS + 1):
			for x in range(center.x - RADIUS, center.x + RADIUS + 1):
				var key := Vector2i(x, z)
				if not tiles.has(key):
					_pending.append(key)
		_pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.distance_squared_to(center) < b.distance_squared_to(center))
	if not _pending.is_empty():
		_build_tile(_pending.pop_front())


func placements_for(key: Vector2i) -> Array[Transform3D]:
	var random := RandomNumberGenerator.new()
	random.seed = hash(key) + 63031
	var result: Array[Transform3D] = []
	for z in range(GRID):
		for x in range(GRID):
			var local := Vector2((x + random.randf_range(0.2, 0.8)) * TILE / GRID,
				(z + random.randf_range(0.2, 0.8)) * TILE / GRID)
			var point := Vector2(key.x * TILE, key.y * TILE) + local
			if not field.can_grow(point.x, point.y):
				continue
			var height: float = field.ground.surface_height(point.x, point.y)
			var pose := Basis(Vector3.UP, random.randf_range(0, TAU))
			result.append(Transform3D(pose, Vector3(local.x, height - 0.02, local.y)))
	return result


func _build_tile(key: Vector2i) -> void:
	var placements := placements_for(key)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _mesh
	multi.instance_count = placements.size()
	for index in range(placements.size()):
		multi.set_instance_transform(index, placements[index])
	var tile := MultiMeshInstance3D.new()
	tile.multimesh = multi
	tile.material_override = _material
	tile.position = Vector3(key.x * TILE, 0, key.y * TILE)
	tile.extra_cull_margin = 0.3
	tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tile)
	tiles[key] = tile


func _make_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for side in range(2):
		var base := vertices.size()
		for point in [Vector2(-1.25, 0), Vector2(1.25, 0),
				Vector2(-1.25, 0.55), Vector2(1.25, 0.55)]:
			vertices.append(Vector3(point.x, point.y, 0).rotated(Vector3.UP, side * PI * 0.5))
			normals.append(Vector3.UP)
			uv.append(Vector2((point.x + 1.25) / 2.5, 1.0 - point.y / 0.55))
		for index in [0, 2, 1, 1, 2, 3]:
			indices.append(base + index)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
