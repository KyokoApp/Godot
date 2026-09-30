extends Node3D
## Pulau deterministik 1 km, terrain ber-collision dengan jalan menyatu permukaan.
## 16 chunk, total 80.000 segitiga; tanpa shader/tekstur eksternal.

const ArenaShape = preload("res://src/game/arena/arena_shape.gd")
const WaterShape = preload("res://src/game/water/water_shape.gd")
const WaterSurfaces = preload("res://src/game/water/water_surfaces.gd")
const TERRAIN_SHADER = preload("res://src/game/terrain.gdshader")
const SIZE := 1000.0
const STEP := 5.0
const CELLS := 200
const CHUNK := 50
const SEA_LEVEL := 0.0
const GRASS_COLOR := Color("59a541")
const DIRT_COLOR := Color("a97848")
const CLIFF_COLOR := Color("777c7e")
const SAND_COLOR := Color("c9ad72")

## Vector3(x, rayon_horizontal, z) untuk mengosongkan rumput di bawah batu.
var water: WaterSurfaces

var rock_clearances: Array[Vector3] = []

var _terrain_material: ShaderMaterial
var _heights := PackedFloat32Array()


func _ready() -> void:
	name = "Island"
	_terrain_material = ShaderMaterial.new()
	_terrain_material.shader = TERRAIN_SHADER
	_terrain_material.set_shader_parameter("dirt_color", DIRT_COLOR)
	_terrain_material.set_shader_parameter("meadow_cover",
		preload("res://assets/nature/meadow_cover.png"))
	_heights.resize((CELLS + 1) * (CELLS + 1))
	for z in range(CELLS + 1):
		for x in range(CELLS + 1):
			_heights[z * (CELLS + 1) + x] = terrain_height(x * STEP - 500, z * STEP - 500)
	for z in range(0, CELLS, CHUNK):
		for x in range(0, CELLS, CHUNK):
			_build_chunk(x, z)
	_build_sea()
	_build_rocks()
	water = WaterSurfaces.new()
	water.island = self
	add_child(water)


static func road_x(z: float) -> float:
	return 65.0 * sin(z / 95.0) + 22.0 * sin(z / 43.0)


static func road_height(z: float) -> float:
	# Broad rise plus gentle ~176m undulations; no small bumps underfoot.
	return 5.0 + 7.0 * (1.0 - cos(z / 110.0)) + 1.1 * (1.0 - cos(z / 28.0))


static func road_distance(x: float, z: float) -> float:
	# Local perpendicular distance keeps the width steady through bends.
	var slope := (65.0 / 95.0) * cos(z / 95.0) + (22.0 / 43.0) * cos(z / 43.0)
	return absf(x - road_x(z)) / sqrt(1.0 + slope * slope)


static func road_mask(x: float, z: float) -> float:
	return (1.0 - smoothstep(9.0, 11.0, road_distance(x, z))) * (
		1.0 - smoothstep(300.0, 335.0, absf(z)))


static func terrain_height(x: float, z: float) -> float:
	var angle := atan2(z, x)
	var radius := 435.0 + 22.0 * sin(angle * 3.0) + 18.0 * cos(angle * 5.0)
	var inland := radius - Vector2(x, z).length()
	var coast := smoothstep(-20.0, 85.0, inland)
	var hills := 48.0 * exp(-Vector2(x + 160, z + 110).length_squared() / 17000.0)
	hills += 35.0 * exp(-Vector2(x - 120, z - 180).length_squared() / 12000.0)
	# Dataran tinggi timur dengan sisi curam berbatu, bukan sekadar gundukan hijau.
	var cliff := 44.0 * (1.0 - smoothstep(65.0, 92.0, Vector2(x - 230, z + 110).length()))
	var rolling := 3.0 * sin(x / 48.0) * cos(z / 61.0)
	var height := -7.0 + coast * (12.0 + hills + cliff + rolling)
	var road_weight := 1.0 - smoothstep(13.0, 38.0, road_distance(x, z))
	road_weight *= 1.0 - smoothstep(300.0, 350.0, absf(z))
	return ArenaShape.carve(x, z,
		WaterShape.carve(x, z, lerpf(height, road_height(z), road_weight)))


func surface_height(x: float, z: float) -> float:
	# Interpolasi segitiga SAMA dengan mesh collider, bukan fungsi halus perkiraan.
	var gx := clampf((x + 500.0) / STEP, 0.0, CELLS - 0.001)
	var gz := clampf((z + 500.0) / STEP, 0.0, CELLS - 0.001)
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


func is_walkable_shore(x: float, z: float) -> bool:
	var water_level := SEA_LEVEL
	if WaterShape.covers(x, z):
		water_level = maxf(water_level, WaterShape.level(x, z))
	return surface_height(x, z) >= water_level + 0.6


func _height(x: int, z: int) -> float:
	return _heights[clampi(z, 0, CELLS) * (CELLS + 1) + clampi(x, 0, CELLS)]


func _color(x: float, z: float, height: float, normal: Vector3) -> Color:
	return _land_color(height, normal).lerp(DIRT_COLOR, road_mask(x, z))


func _land_color(height: float, normal: Vector3) -> Color:
	# Warna solid: hijau di bidang datar, batu di sisi curam, bukan berdasarkan tinggi.
	var color := GRASS_COLOR.lerp(CLIFF_COLOR, 1.0 - smoothstep(0.65, 0.88, normal.y))
	color = SAND_COLOR.lerp(color, smoothstep(1.0, 5.0, height))
	return color


func _build_chunk(start_x: int, start_z: int) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for z in range(start_z, start_z + CHUNK + 1):
		for x in range(start_x, start_x + CHUNK + 1):
			var point := Vector3(x * STEP - 500, _height(x, z), z * STEP - 500)
			var normal := Vector3(_height(x - 1, z) - _height(x + 1, z), STEP * 2,
				_height(x, z - 1) - _height(x, z + 1)).normalized()
			vertices.append(point)
			normals.append(normal)
			colors.append(_land_color(point.y, normal))
	for z in range(CHUNK):
		for x in range(CHUNK):
			var a := z * (CHUNK + 1) + x
			var b := a + 1
			var c := a + CHUNK + 1
			var d := c + 1
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	_facet_cliffs(arrays)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := _terrain_material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	add_child(visual)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)


func _build_sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(4000, 4000)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("65b9c8")
	material.roughness = 0.28
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = plane
	sea.material_override = material
	sea.position.y = SEA_LEVEL
	add_child(sea)


func _build_rocks() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 42017
	var source := SphereMesh.new()
	source.radial_segments = 7
	source.rings = 3
	var rock_mesh := _flat_rock(source)
	for index in range(60):
		var x := random.randf_range(-370, 370)
		var z := random.randf_range(-370, 370)
		var y := surface_height(x, z)
		if ArenaShape.distance_to(x, z) < 5:
			continue
		if y < 2.0 or road_distance(x, z) < 24.0 or WaterShape.covers(x, z, 5.0):
			continue
		var rock := MeshInstance3D.new()
		rock.mesh = rock_mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = CLIFF_COLOR.lerp(Color("8b8880"), random.randf())
		material.roughness = 1.0
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		rock.material_override = material
		rock.position = Vector3(x, y, z)
		rock.scale = Vector3(random.randf_range(3, 9), random.randf_range(2, 8),
			random.randf_range(3, 9))
		rock.rotation.y = random.randf_range(0, TAU)
		rock_clearances.append(Vector3(x, maxf(rock.scale.x, rock.scale.z) * 0.5, z))
		add_child(rock)
		rock.create_convex_collision()


func _facet_cliffs(arrays: Array) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for face in range(0, indices.size(), 3):
		var a := vertices[indices[face]]
		var b := vertices[indices[face + 1]]
		var c := vertices[indices[face + 2]]
		var normal := (c - a).cross(b - a).normalized()
		var center := (a + b + c) / 3.0
		if normal.y >= 0.72 or center.y < 5.0:
			continue
		# Pisah vertex sisi curam agar bidang batu terlihat tegas/low-poly.
		for corner in range(3):
			var vertex := vertices[indices[face + corner]]
			indices[face + corner] = vertices.size()
			vertices.append(vertex)
			normals.append(normal)
			colors.append(CLIFF_COLOR)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices


func _flat_rock(source: Mesh) -> ArrayMesh:
	var vertices := source.get_faces()
	var normals := PackedVector3Array()
	for face in range(0, vertices.size(), 3):
		var normal := (vertices[face + 2] - vertices[face]).cross(
			vertices[face + 1] - vertices[face]).normalized()
		for corner in range(3):
			normals.append(normal)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func set_grass_cover(enabled: bool) -> void:
	if _terrain_material != null:
		_terrain_material.set_shader_parameter("grass_cover_enabled", enabled)
