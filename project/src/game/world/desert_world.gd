extends Node3D
## A broad dune field with a coarse distance ring and mesa silhouettes at the horizon.

const GROUND_SHADER = preload("res://src/game/desert_ground.gdshader")
const SAND_ALBEDO: Texture2D = preload("res://assets/desert/sand_albedo.png")

const PLAYABLE_HALF := 360.0
const NEAR_HALF := 256.0
const NEAR_STEP := 2.0
const WORLD_HALF := 1024.0
const FAR_STEP := 16.0
const DUNE_AXIS := Vector2(0.82, 0.57)

static var _broad_noise: FastNoiseLite
static var _warp_x: FastNoiseLite
static var _warp_z: FastNoiseLite
static var _detail_noise: FastNoiseLite

var _ground_material: ShaderMaterial
var _stone_material: StandardMaterial3D


func _ready() -> void:
	name = "Desert"
	_prepare_noise()
	_build_materials()
	_build_near_ground()
	_build_far_ground()
	_build_mesas()


func _build_materials() -> void:
	_ground_material = ShaderMaterial.new()
	_ground_material.shader = GROUND_SHADER
	_ground_material.set_shader_parameter("sand_albedo", SAND_ALBEDO)
	_ground_material.set_shader_parameter("wind_axis", DUNE_AXIS)
	_stone_material = StandardMaterial3D.new()
	_stone_material.vertex_color_use_as_albedo = true
	_stone_material.roughness = 0.98
	_stone_material.specular = 0.08
	_stone_material.cull_mode = BaseMaterial3D.CULL_DISABLED


func _build_near_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "NearDunes"
	ground.mesh = _make_ground_mesh(NEAR_HALF, NEAR_STEP, false)
	ground.material_override = _ground_material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _build_far_ground() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "FarDunes"
	ground.mesh = _make_ground_mesh(WORLD_HALF, FAR_STEP, true)
	ground.material_override = _ground_material
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.extra_cull_margin = 8.0
	add_child(ground)


func _make_ground_mesh(extent: float, step: float, leave_near_hole: bool) -> ArrayMesh:
	var cells := int(round(extent * 2.0 / step))
	var side := cells + 1
	var heights := PackedFloat32Array()
	heights.resize(side * side)
	var vertices := PackedVector3Array()
	vertices.resize(side * side)
	for z in range(side):
		var world_z := -extent + z * step
		for x in range(side):
			var world_x := -extent + x * step
			var index := z * side + x
			var height := terrain_height(world_x, world_z)
			heights[index] = height
			vertices[index] = Vector3(world_x, height, world_z)

	var normals := PackedVector3Array()
	normals.resize(side * side)
	var uvs := PackedVector2Array()
	uvs.resize(side * side)
	for z in range(side):
		for x in range(side):
			var index := z * side + x
			var left_x := maxi(x - 1, 0)
			var right_x := mini(x + 1, cells)
			var back_z := maxi(z - 1, 0)
			var front_z := mini(z + 1, cells)
			var dx := (heights[z * side + right_x] - heights[z * side + left_x]) \
				/ (float(right_x - left_x) * step)
			var dz := (heights[front_z * side + x] - heights[back_z * side + x]) \
				/ (float(front_z - back_z) * step)
			normals[index] = Vector3(-dx, 1.0, -dz).normalized()
			uvs[index] = Vector2(vertices[index].x, vertices[index].z)

	var indices := PackedInt32Array()
	for z in range(cells):
		var center_z := -extent + (z + 0.5) * step
		for x in range(cells):
			var center_x := -extent + (x + 0.5) * step
			if leave_near_hole and absf(center_x) < NEAR_HALF \
					and absf(center_z) < NEAR_HALF:
				continue
			var a := z * side + x
			var b := a + 1
			var c := a + side
			var d := c + 1
			# This order faces upward in Godot's XZ ground plane.
			indices.append(a)
			indices.append(c)
			indices.append(b)
			indices.append(b)
			indices.append(c)
			indices.append(d)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_mesas() -> void:
	var sites: Array[Dictionary] = [
		{"name": "Northwest Mesa", "position": Vector2(-510, -490),
			"radius": Vector2(150, 100), "height": 110.0, "seed": 1.4},
		{"name": "Northeast Butte", "position": Vector2(500, -560),
			"radius": Vector2(100, 75), "height": 76.0, "seed": 4.7},
		{"name": "East Mesa", "position": Vector2(590, 40),
			"radius": Vector2(145, 85), "height": 120.0, "seed": 8.2},
		{"name": "Southeast Mesa", "position": Vector2(500, 520),
			"radius": Vector2(132, 82), "height": 98.0, "seed": 11.3},
		{"name": "Southwest Butte", "position": Vector2(-560, 520),
			"radius": Vector2(112, 72), "height": 82.0, "seed": 14.6},
	]
	for site in sites:
		_build_mesa(site)


func _build_mesa(site: Dictionary) -> void:
	var center: Vector2 = site["position"]
	var radius: Vector2 = site["radius"]
	var height := float(site["height"])
	var seed := float(site["seed"])
	var base_height := terrain_height(center.x, center.y)
	var segment_count := 40
	var ring_heights: Array[float] = [0.0, 0.13, 0.17, 0.61, 0.66, 0.91, 0.95, 1.0]
	var ring_widths: Array[float] = [1.06, 1.00, 0.83, 0.79, 0.72, 0.70, 0.61, 0.51]
	var ring_colors: Array[Color] = [
		Color(0.47, 0.32, 0.21), Color(0.65, 0.46, 0.30),
		Color(0.77, 0.56, 0.37), Color(0.56, 0.38, 0.25),
		Color(0.80, 0.60, 0.40), Color(0.61, 0.42, 0.28),
		Color(0.86, 0.68, 0.48), Color(0.92, 0.76, 0.56),
	]
	var rings: Array[PackedVector3Array] = []
	for ring_index in range(ring_heights.size()):
		var ring := PackedVector3Array()
		for segment in range(segment_count):
			var angle := TAU * float(segment) / segment_count
			var outline := 1.0 + 0.055 * sin(angle * 3.0 + seed) \
				+ 0.028 * sin(angle * 7.0 - seed * 1.7)
			var x := cos(angle) * radius.x * ring_widths[ring_index] * outline
			var z := sin(angle) * radius.y * ring_widths[ring_index] * outline
			var local_height := 0.0
			if ring_index == 0:
				local_height = terrain_height(center.x + x, center.y + z) - base_height
			else:
				local_height = height * ring_heights[ring_index] \
					+ sin(angle * 5.0 + seed) * height * 0.012
			ring.append(Vector3(x, local_height, z))
		rings.append(ring)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring_index in range(rings.size() - 1):
		for segment in range(segment_count):
			var next := (segment + 1) % segment_count
			var lower_a: Vector3 = rings[ring_index][segment]
			var lower_b: Vector3 = rings[ring_index][next]
			var upper_a: Vector3 = rings[ring_index + 1][segment]
			var upper_b: Vector3 = rings[ring_index + 1][next]
			var outward := Vector3(
				(lower_a.x + lower_b.x + upper_a.x + upper_b.x) / (4.0 * radius.x * radius.x),
				0.0,
				(lower_a.z + lower_b.z + upper_a.z + upper_b.z) / (4.0 * radius.y * radius.y))
			var band_color: Color = ring_colors[ring_index]
			_add_mesa_triangle(surface, lower_a, lower_b, upper_a, band_color, outward)
			_add_mesa_triangle(surface, lower_b, upper_b, upper_a,
				band_color.lightened(0.025), outward)
	var top_center := Vector3(0.0, height, 0.0)
	var top_ring: PackedVector3Array = rings.back()
	for segment in range(segment_count):
		var next := (segment + 1) % segment_count
		_add_mesa_triangle(surface, top_center, top_ring[segment], top_ring[next],
			ring_colors.back(), Vector3.UP)
	surface.generate_normals()
	var mesa := MeshInstance3D.new()
	mesa.name = str(site["name"])
	mesa.mesh = surface.commit()
	mesa.material_override = _stone_material
	mesa.position = Vector3(center.x, base_height, center.y)
	mesa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesa.extra_cull_margin = 6.0
	add_child(mesa)


func _add_mesa_triangle(
	surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color,
	expected_normal: Vector3
) -> void:
	var second := b
	var third := c
	if (second - a).cross(third - a).dot(expected_normal) < 0.0:
		second = c
		third = b
	surface.set_color(color)
	surface.add_vertex(a)
	surface.set_color(color)
	surface.add_vertex(second)
	surface.set_color(color)
	surface.add_vertex(third)


func surface_height(x: float, z: float) -> float:
	return terrain_height(x, z)


func clamp_inside(point: Vector2, margin: float = 0.0) -> Vector2:
	var limit := maxf(1.0, PLAYABLE_HALF - maxf(margin, 0.0))
	return Vector2(clampf(point.x, -limit, limit), clampf(point.y, -limit, limit))


func is_inside(x: float, z: float, margin: float = 0.0) -> bool:
	var limit := PLAYABLE_HALF - maxf(margin, 0.0)
	return absf(x) <= limit and absf(z) <= limit


static func terrain_height(x: float, z: float) -> float:
	_prepare_noise()
	var warp_x := _warp_x.get_noise_2d(x, z) * 38.0
	var warp_z := _warp_z.get_noise_2d(x, z) * 38.0
	var point := Vector2(x, z)
	var along := point.dot(DUNE_AXIS)
	var across := point.dot(Vector2(DUNE_AXIS.y, -DUNE_AXIS.x))
	var phase := (along + warp_x) * 0.018 \
		+ sin((across + warp_z) * 0.006 + warp_x * 0.012) * 1.02
	var dune := sin(phase) * 8.0 \
		+ sin(phase * 0.50 + warp_z * 0.018) * 2.2 \
		+ sin(phase * 1.95 + 0.6) * 0.72
	var shoulder_phase := (along + warp_x * 0.55) * 0.052 \
		+ sin((across + warp_z) * 0.018 + warp_x * 0.008) * 0.42
	var shoulder_dunes := sin(shoulder_phase) * 2.8 \
		+ sin(shoulder_phase * 1.9 + 1.1) * 0.44
	var ripple_phase := (along + warp_x * 0.3) * 0.092 \
		+ (across + warp_z * 0.75) * 0.016
	var small_ridges := sin(ripple_phase) * 0.9
	var broad := _broad_noise.get_noise_2d(x, z) * 2.4
	var fine := _detail_noise.get_noise_2d(x, z) * 0.48
	return 16.0 + dune + shoulder_dunes + small_ridges + broad + fine


static func _prepare_noise() -> void:
	if _broad_noise != null:
		return
	_broad_noise = FastNoiseLite.new()
	_broad_noise.seed = 29173
	_broad_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_broad_noise.frequency = 0.0042
	_broad_noise.fractal_octaves = 3
	_broad_noise.fractal_lacunarity = 2.1
	_broad_noise.fractal_gain = 0.48
	_warp_x = FastNoiseLite.new()
	_warp_x.seed = 4171
	_warp_x.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_warp_x.frequency = 0.0034
	_warp_x.fractal_octaves = 2
	_warp_z = FastNoiseLite.new()
	_warp_z.seed = 8827
	_warp_z.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_warp_z.frequency = 0.0031
	_warp_z.fractal_octaves = 2
	_detail_noise = FastNoiseLite.new()
	_detail_noise.seed = 12761
	_detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_detail_noise.frequency = 0.018
	_detail_noise.fractal_octaves = 2
