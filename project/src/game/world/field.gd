extends Node3D
## Padang latihan 100 m × 100 m. Satu medan rumput bergelombang halus, ber-collision,
## dengan fungsi tinggi yang SAMA dipakai mesh, karakter, dan rumput.
## Menggantikan pulau 1 km, laut, jalan berliku, dan arena.

const SHADER = preload("res://src/game/ground.gdshader")
const MEADOW = preload("res://assets/nature/meadow_cover.png")
const SIZE := 100.0
const HALF := SIZE * 0.5
const STEP := 1.0
const CELLS := 100
const CHUNK_CELLS := 25
const WALK_MARGIN := 0.7
const HEIGHT_AMPLITUDE := 0.55
const GRASS_COLOR := Color("8fce63")
const GRASS_DARK := Color("6aa845")
const DIRT_COLOR := Color("c9a873")

var _heights := PackedFloat32Array()
var _material: ShaderMaterial
var _grass_cover := true


func _ready() -> void:
	name = "Field"
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("meadow_cover", MEADOW)
	_material.set_shader_parameter("grass_color", GRASS_COLOR)
	_material.set_shader_parameter("grass_dark", GRASS_DARK)
	_material.set_shader_parameter("edge_color", DIRT_COLOR)
	_material.set_shader_parameter("half_size", HALF)
	_material.set_shader_parameter("edge_begin", HALF - 4.5)
	_heights.resize((CELLS + 1) * (CELLS + 1))
	for z in range(CELLS + 1):
		for x in range(CELLS + 1):
			_heights[z * (CELLS + 1) + x] = terrain_height(
				x * STEP - HALF, z * STEP - HALF)
	for z in range(0, CELLS, CHUNK_CELLS):
		for x in range(0, CELLS, CHUNK_CELLS):
			_build_chunk(x, z)


static func terrain_height(x: float, z: float) -> float:
	# Gelombang panjang ≤ 0.9 m: enak dipandang, tidak mengganggu kaki animasi.
	var waves := 0.34 * sin(x / 8.5) * cos(z / 9.5)
	waves += 0.18 * sin((x + z) / 12.0) + 0.12 * cos((x - z) / 6.5)
	var bowl := 0.00013 * (x * x + z * z)
	return waves * HEIGHT_AMPLITUDE + bowl


static func clamp_inside(point: Vector2, margin: float) -> Vector2:
	var limit := HALF - margin
	return Vector2(clampf(point.x, -limit, limit), clampf(point.y, -limit, limit))


func surface_height(x: float, z: float) -> float:
	# Interpolasi segitiga yang sama dengan collider, bukan perkiraan halus.
	var gx := clampf((x + HALF) / STEP, 0.0, CELLS - 0.001)
	var gz := clampf((z + HALF) / STEP, 0.0, CELLS - 0.001)
	var ix := int(gx)
	var iz := int(gz)
	var fx := gx - ix
	var fz := gz - iz
	var a := _height(ix, iz)
	var b := _height(ix + 1, iz)
	var c := _height(ix, iz + 1)
	var d := _height(ix + 1, iz + 1)
	if fx + fz <= 1.0:
		return a + (b - a) * fx + (c - a) * fz
	return d + (c - d) * (1.0 - fx) + (b - d) * (1.0 - fz)


func is_inside(x: float, z: float, margin := 0.0) -> bool:
	var limit := HALF - margin
	return absf(x) <= limit and absf(z) <= limit


func can_grow(x: float, z: float) -> bool:
	if not is_inside(x, z, WALK_MARGIN):
		return false
	var gradient := Vector2(
		surface_height(x + 0.5, z) - surface_height(x - 0.5, z),
		surface_height(x, z + 0.5) - surface_height(x, z - 0.5))
	if gradient.length() > 0.30:
		return false
	return true


func set_grass_cover(enabled: bool) -> void:
	# Dipakai rumput untuk menghilangkan pola tanah saat rumput disembunyikan.
	_grass_cover = enabled
	if _material != null:
		_material.set_shader_parameter("cover_enabled", enabled)


func _height(x: int, z: int) -> float:
	return _heights[clampi(z, 0, CELLS) * (CELLS + 1) + clampi(x, 0, CELLS)]


func _tint(x: float, z: float) -> float:
	var patch := sin(x * 0.13) * cos(z * 0.11) + 0.55 * sin((x + z) * 0.045)
	return clampf(1.0 + 0.07 * patch, 0.90, 1.10)


func _build_chunk(start_x: int, start_z: int) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for z in range(start_z, start_z + CHUNK_CELLS + 1):
		for x in range(start_x, start_x + CHUNK_CELLS + 1):
			var point := Vector3(x * STEP - HALF, _height(x, z), z * STEP - HALF)
			var normal := Vector3(_height(x - 1, z) - _height(x + 1, z), STEP * 2.0,
				_height(x, z - 1) - _height(x, z + 1)).normalized()
			vertices.append(point)
			normals.append(normal)
			var tint := _tint(point.x, point.z)
			colors.append(Color(tint, tint, tint))
	for z in range(CHUNK_CELLS):
		for x in range(CHUNK_CELLS):
			var a := z * (CHUNK_CELLS + 1) + x
			var b := a + 1
			var c := a + CHUNK_CELLS + 1
			var d := c + 1
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var visual := MeshInstance3D.new()
	visual.name = "Ground_%d_%d" % [start_x, start_z]
	visual.mesh = mesh
	visual.material_override = _material
	add_child(visual)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)
