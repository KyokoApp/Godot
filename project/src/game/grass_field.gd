extends Node3D
## Rumput berlapis di pulau 500 m: helai rapat + lapisan bawah sampai 24 m,
## lalu makin renggang sampai 36 m, lalu kartu LOD (distant_grass.gd) sampai 128 m.
## Jarak tile tetap mengikuti pemain (radius 3 tile = 36 m), jadi kepadatan dan
## biaya gambar TIDAK berubah walau dunianya kini 500 m — yang menentukan adalah
## `Field.can_grow()`, bukan ukuran dunia.

const DistantGrass = preload("res://src/game/world/distant_grass.gd")
const Field = preload("res://src/game/world/field.gd")
const SHADER = preload("res://src/game/grass.gdshader")
const TILE_SIZE := 12.0
const GRID := 44
const FAR_GRID := 22
const RADIUS := 3
## Tile dengan helai rapat + lapisan bawah: cakupan 24 m dari pemain (5x5 tile).
## Di luar itu rumpunnya menipis (FAR_GRID) supaya transisi ke kartu LOD halus.
const NEAR_SPAN := 2
const MAX_TILES := (RADIUS * 2 + 1) ** 2
const NEAR_TILES := (NEAR_SPAN * 2 + 1) ** 2
const MAX_CLUMPS := NEAR_TILES * GRID * GRID + (MAX_TILES - NEAR_TILES) * FAR_GRID * FAR_GRID
const MAX_TRIANGLES := (NEAR_TILES * GRID * GRID * 6
	+ (MAX_TILES - NEAR_TILES) * FAR_GRID * FAR_GRID * 4)
## Helai KECIL supaya terbaca sebagai helai, bukan semak: tinggi 0,55 -> 0,34 m
## dan lebar 0,085 -> 0,055 m. Lapisan bawah ikut mengecil mengikuti helai.
const COVER_HALF_SIZE := 0.22
const BLADE_WIDTH := 0.055
const BLADE_HEIGHT := 0.34

var distant: DistantGrass
var ground: Field
var player: Node3D
var tiles: Dictionary[Vector2i, MultiMeshInstance3D] = {}
var _pending: Array[Vector2i] = []
var _center := Vector2i(99999, 99999)
var _mesh: ArrayMesh
var _far_mesh: ArrayMesh
var _tile_grids: Dictionary[Vector2i, int] = {}
var _material: ShaderMaterial


func _ready() -> void:
	_mesh = _make_mesh(true)
	_far_mesh = _make_mesh(false)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("wind_noise", _make_noise())
	distant = DistantGrass.new()
	distant.field = self
	add_child(distant)


func _process(_delta: float) -> void:
	if ground == null or player == null:
		return
	var position_3d := player.global_position
	distant.update_center(position_3d)
	_material.set_shader_parameter("player_position", position_3d - Vector3(0, 0.9, 0))
	var center := Vector2i(floori(position_3d.x / TILE_SIZE), floori(position_3d.z / TILE_SIZE))
	if center != _center:
		_recenter(center)
	# Batasi lonjakan CPU: paling banyak satu tile (maksimal 1.936 kandidat) tiap frame.
	if not _pending.is_empty():
		_build_tile(_pending.pop_front())


func _recenter(center: Vector2i) -> void:
	_center = center
	_pending.clear()
	for key in tiles.keys():
		if absi(key.x - center.x) > RADIUS or absi(key.y - center.y) > RADIUS:
			tiles[key].queue_free()
			tiles.erase(key)
			_tile_grids.erase(key)
	for z in range(center.y - RADIUS, center.y + RADIUS + 1):
		for x in range(center.x - RADIUS, center.x + RADIUS + 1):
			var key := Vector2i(x, z)
			if not tiles.has(key) or _tile_grids[key] != grid_for(key):
				_pending.append(key)
	_pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _tile_priority(a) < _tile_priority(b))


func _tile_priority(key: Vector2i) -> float:
	# Turunkan tile lama dulu supaya batas geometri terjaga saat melewati batas sel.
	var downgrade := _tile_grids.has(key) and _tile_grids[key] == GRID and grid_for(key) == FAR_GRID
	return key.distance_squared_to(_center) - (1000.0 if downgrade else 0.0)


func can_grow(x: float, z: float) -> bool:
	return ground != null and ground.can_grow(x, z)


func grid_for(key: Vector2i) -> int:
	var span := maxi(absi(key.x - _center.x), absi(key.y - _center.y))
	return GRID if span <= NEAR_SPAN else FAR_GRID


func placements_for(key: Vector2i) -> Array[Transform3D]:
	var grid := grid_for(key)
	var random := RandomNumberGenerator.new()
	random.seed = hash(key) + 8421
	var placements: Array[Transform3D] = []
	var origin := Vector3(key.x * TILE_SIZE, 0, key.y * TILE_SIZE)
	# Far adalah subset grid dekat, jadi akar tidak berpindah saat ganti LOD.
	for z in range(GRID):
		for x in range(GRID):
			var local_x := (x + random.randf_range(0.25, 0.75)) * TILE_SIZE / GRID
			var local_z := (z + random.randf_range(0.25, 0.75)) * TILE_SIZE / GRID
			var angle := random.randf_range(0, TAU)
			var scale_factor := random.randf_range(0.9, 1.15)
			if grid == FAR_GRID and (x % 2 != 0 or z % 2 != 0):
				continue
			var world_x := origin.x + local_x
			var world_z := origin.z + local_z
			if not can_grow(world_x, world_z):
				continue
			var height := ground.surface_height(world_x, world_z) - 0.03
			var basis := Basis(Vector3.UP, angle)
			basis = basis.scaled(Vector3.ONE * scale_factor)
			# Lapisan bawah mengikuti kemiringan, bukan melayang di atas lereng.
			var dx := (ground.surface_height(world_x + 0.5, world_z)
				- ground.surface_height(world_x - 0.5, world_z))
			var dz := (ground.surface_height(world_x, world_z + 0.5)
				- ground.surface_height(world_x, world_z - 0.5))
			basis.x.y = dx * basis.x.x + dz * basis.x.z
			basis.z.y = dx * basis.z.x + dz * basis.z.z
			placements.append(Transform3D(basis, Vector3(local_x, height, local_z)))
	return placements


func _build_tile(key: Vector2i) -> void:
	var placements := placements_for(key)
	var min_y := INF
	var max_y := -INF
	for placement in placements:
		min_y = minf(min_y, placement.origin.y)
		max_y = maxf(max_y, placement.origin.y)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = _mesh if grid_for(key) == GRID else _far_mesh
	multi.instance_count = placements.size()
	for index in range(placements.size()):
		multi.set_instance_transform(index, placements[index])
		var cell_x := floori(placements[index].origin.x * GRID / TILE_SIZE)
		var cell_z := floori(placements[index].origin.z * GRID / TILE_SIZE)
		var detail := 1.0 if cell_x % 2 != 0 or cell_z % 2 != 0 else 0.0
		multi.set_instance_custom_data(index, Color(detail, 0, 0, 0))
	var tile := MultiMeshInstance3D.new()
	tile.multimesh = multi
	tile.material_override = _material
	tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Bounds mencakup angin/reaksi pemain, supaya tidak terpotong saat kamera berputar.
	if not placements.is_empty():
		tile.custom_aabb = AABB(Vector3(-1, min_y - 0.3, -1),
			Vector3(TILE_SIZE + 2, max_y - min_y + 1.5, TILE_SIZE + 2))
	tile.position = Vector3(key.x * TILE_SIZE, 0, key.y * TILE_SIZE)
	add_child(tile)
	if tiles.has(key):
		tiles[key].queue_free()
	tiles[key] = tile
	_tile_grids[key] = grid_for(key)


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


func _make_mesh(with_cover: bool) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# Empat helai tipis satu segitiga. Kepadatan naik tanpa menggandakan tris.
	for blade in range(4):
		var angle := blade * TAU / 4.0
		var offset := Vector3(0.13, 0, 0).rotated(Vector3.UP, angle)
		var height := BLADE_HEIGHT * (0.8 if blade % 2 == 0 else 1.0)
		var points: Array[Vector3] = [Vector3(-BLADE_WIDTH / 2.0, 0, 0),
			Vector3(BLADE_WIDTH / 2.0, 0, 0), Vector3(0.025, height, 0.09)]
		for point in points:
			indices.append(vertices.size())
			vertices.append(point.rotated(Vector3.UP, angle) + offset)
			normals.append(Vector3.UP)
			uvs.append(Vector2(0.5, 1.0 - point.y / BLADE_HEIGHT))
	if with_cover:
		# Penutup rendah 5 cm: quad opaque bertumpuk di bawah helai tinggi.
		# UV.x membedakannya agar shader memberi corak daun pendek, bukan tanah polos.
		var base := vertices.size()
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			vertices.append(Vector3(corner.x * COVER_HALF_SIZE, 0.08,
				corner.y * COVER_HALF_SIZE))
			normals.append(Vector3.UP)
			uvs.append(Vector2(2.0, 0.80))
		for index in [0, 1, 2, 1, 3, 2]:
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_instance_valid(ground):
		ground.set_grass_cover(is_visible_in_tree())
