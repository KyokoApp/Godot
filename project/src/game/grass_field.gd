extends Node3D
## Rumput streamed: maksimum 25 tile / 10.000 rumpun, bukan memenuhi seluruh 1 km.

const Island = preload("res://src/game/island.gd")
const SHADER = preload("res://src/game/grass.gdshader")
const TILE_SIZE := 12.0
const GRID := 20
const RADIUS := 2
const MAX_TILES := 25

var island: Island
var player: Node3D
var tiles: Dictionary[Vector2i, MultiMeshInstance3D] = {}
var _pending: Array[Vector2i] = []
var _center := Vector2i(99999, 99999)
var _mesh: ArrayMesh
var _material: ShaderMaterial


func _ready() -> void:
	_mesh = _make_mesh()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("wind_noise", _make_noise())


func _process(_delta: float) -> void:
	if island == null or player == null:
		return
	var position_3d := player.global_position
	_material.set_shader_parameter("player_position", position_3d - Vector3(0, 0.9, 0))
	var center := Vector2i(floori(position_3d.x / TILE_SIZE), floori(position_3d.z / TILE_SIZE))
	if center != _center:
		_recenter(center)
	# Batasi lonjakan CPU: paling banyak satu tile (400 kandidat) tiap frame.
	if not _pending.is_empty():
		_build_tile(_pending.pop_front())


func _recenter(center: Vector2i) -> void:
	_center = center
	_pending.clear()
	for key in tiles.keys():
		if absi(key.x - center.x) > RADIUS or absi(key.y - center.y) > RADIUS:
			tiles[key].queue_free()
			tiles.erase(key)
	for z in range(center.y - RADIUS, center.y + RADIUS + 1):
		for x in range(center.x - RADIUS, center.x + RADIUS + 1):
			var key := Vector2i(x, z)
			if not tiles.has(key):
				_pending.append(key)
	_pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(center) < b.distance_squared_to(center))


func can_grow(x: float, z: float) -> bool:
	if absf(x) > 495 or absf(z) > 495:
		return false
	var height := island.surface_height(x, z)
	if height < 5.4:
		return false
	# Margin tambahan menahan daun yang tertiup angin agar tidak masuk jalan.
	if absf(z) < 340 and absf(x - Island.road_x(z)) < 17.0:
		return false
	var gradient := Vector2(
		island.surface_height(x + 1, z) - island.surface_height(x - 1, z),
		island.surface_height(x, z + 1) - island.surface_height(x, z - 1)) * 0.5
	if gradient.length() > 0.45:
		return false
	for rock in island.rock_clearances:
		if Vector2(x - rock.x, z - rock.z).length() < rock.y + 0.7:
			return false
	return true


func _build_tile(key: Vector2i) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = hash(key) + 8421
	var placements: Array[Transform3D] = []
	var min_y := INF
	var max_y := -INF
	var origin := Vector3(key.x * TILE_SIZE, 0, key.y * TILE_SIZE)
	for z in range(GRID):
		for x in range(GRID):
			var local_x := (x + random.randf_range(0.15, 0.85)) * TILE_SIZE / GRID
			var local_z := (z + random.randf_range(0.15, 0.85)) * TILE_SIZE / GRID
			var world_x := origin.x + local_x
			var world_z := origin.z + local_z
			if not can_grow(world_x, world_z):
				continue
			var height := island.surface_height(world_x, world_z) - 0.03
			min_y = minf(min_y, height)
			max_y = maxf(max_y, height)
			var basis := Basis(Vector3.UP, random.randf_range(0, TAU))
			basis = basis.scaled(Vector3.ONE * random.randf_range(0.8, 1.2))
			placements.append(Transform3D(basis, Vector3(local_x, height, local_z)))
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _mesh
	multi.instance_count = placements.size()
	for index in range(placements.size()):
		multi.set_instance_transform(index, placements[index])
	var tile := MultiMeshInstance3D.new()
	tile.multimesh = multi
	tile.material_override = _material
	tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Bounds mencakup angin/reaksi pemain, supaya tidak terpotong saat kamera berputar.
	if not placements.is_empty():
		tile.custom_aabb = AABB(Vector3(-1, min_y - 0.3, -1),
			Vector3(TILE_SIZE + 2, max_y - min_y + 1.5, TILE_SIZE + 2))
	tile.position = origin
	add_child(tile)
	tiles[key] = tile


func _make_noise() -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 3027
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.07
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 1.5
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	# Periodic blend menjaga tepi tekstur repeat tidak meloncat.
	for y in range(64):
		for x in range(64):
			var top := lerpf(noise.get_noise_2d(x, y), noise.get_noise_2d(x - 64, y), x / 64.0)
			var bottom := lerpf(noise.get_noise_2d(x, y - 64),
				noise.get_noise_2d(x - 64, y - 64), x / 64.0)
			var value := lerpf(top, bottom, y / 64.0) * 0.5 + 0.5
			image.set_pixel(x, y, Color(value, value, value))
	return ImageTexture.create_from_image(image)


func _make_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# Tiga helai meruncing, masing-masing 3 segitiga; bukan quad transparan.
	for blade in range(3):
		var angle := blade * TAU / 3.0
		var offset := Vector3(0.13, 0, 0).rotated(Vector3.UP, angle)
		var points: Array[Vector3] = [Vector3(-0.10, 0, 0), Vector3(0.10, 0, 0),
			Vector3(-0.065, 0.30, 0.03), Vector3(0.065, 0.30, 0.03), Vector3(0, 0.62, 0.09)]
		var base := vertices.size()
		for point in points:
			vertices.append(point.rotated(Vector3.UP, angle) + offset)
			normals.append(Vector3.UP)
			uvs.append(Vector2(0.5, 1.0 - point.y / 0.62))
		for index in [0, 1, 2, 1, 3, 2, 2, 3, 4]:
			indices.append(base + index)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
