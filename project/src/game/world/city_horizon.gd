extends Node3D
## Skyline dan bukit jauh berkabut untuk Scenery home; tanpa fisika/shadow.

const HAZE_SHADER = preload("res://src/game/world/horizon_haze.gdshader")

const BUILDING_COUNT := 56
const CITY_RADIUS := 235.0
const HILL_SEGMENTS := 72
const MIST_COLOR := Color("#303448")

var building_count := 0
var hill_layer_count := 0
var skyline: MultiMeshInstance3D
var hills: Node3D
var _random := RandomNumberGenerator.new()
var _haze_material: ShaderMaterial


func _ready() -> void:
	name = "CityHorizon"
	_random.seed = 20261005
	_haze_material = _make_haze_material()
	_build_skyline()
	_build_hills()


func _make_haze_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = HAZE_SHADER
	material.set_shader_parameter("mist_color", MIST_COLOR)
	material.set_shader_parameter("haze_start", 65.0)
	material.set_shader_parameter("haze_end", 300.0)
	material.set_shader_parameter("haze_strength", 0.95)
	return material


func _build_skyline() -> void:
	var block := BoxMesh.new()
	block.size = Vector3.ONE
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.mesh = block
	instances.instance_count = BUILDING_COUNT
	for index in BUILDING_COUNT:
		var angle := TAU * (float(index) + _random.randf_range(-0.28, 0.28)) \
			/ float(BUILDING_COUNT)
		var distance := CITY_RADIUS + _random.randf_range(-14.0, 18.0)
		var width := _random.randf_range(2.8, 6.8)
		var depth := _random.randf_range(3.0, 7.5)
		var height := _random.randf_range(9.0, 31.0)
		if index % 9 == 0:
			height += 8.0
		var position := Vector3(cos(angle) * distance, height * 0.5 - 3.0,
			sin(angle) * distance)
		var basis := Basis(Vector3.UP, angle + PI * 0.5).scaled(
			Vector3(width, height, depth))
		instances.set_instance_transform(index, Transform3D(basis, position))
		var shade := _random.randf_range(0.70, 1.05)
		instances.set_instance_color(index, Color(0.31, 0.34, 0.46) * shade)
	skyline = MultiMeshInstance3D.new()
	skyline.name = "DistantSkyline"
	skyline.multimesh = instances
	skyline.material_override = _haze_material
	skyline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skyline.extra_cull_margin = 24.0
	add_child(skyline)
	building_count = BUILDING_COUNT


func _build_hills() -> void:
	hills = Node3D.new()
	hills.name = "FogboundHills"
	add_child(hills)
	_add_hill_layer(306.0, 28.0, 16.0, 31.0, 0.4, Color("#55576f"))
	_add_hill_layer(374.0, 38.0, 21.0, 43.0, 2.1, Color("#6a6b82"))
	hill_layer_count = hills.get_child_count()


func _add_hill_layer(radius: float, width: float, base_height: float,
		peak_height: float, phase: float, shade: Color) -> void:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var inner_radius := radius - width * 0.5
	var outer_radius := radius + width * 0.5
	var bottom := -24.0
	for segment in HILL_SEGMENTS:
		var a0 := TAU * float(segment) / float(HILL_SEGMENTS)
		var a1 := TAU * float(segment + 1) / float(HILL_SEGMENTS)
		var h0 := _ridge_height(a0, base_height, peak_height, phase)
		var h1 := _ridge_height(a1, base_height, peak_height, phase)
		var outer_h0 := h0 - 2.0
		var outer_h1 := h1 - 2.0
		var inner_bottom_0 := _ring_point(inner_radius, bottom, a0)
		var inner_bottom_1 := _ring_point(inner_radius, bottom, a1)
		var inner_top_0 := _ring_point(inner_radius, h0, a0)
		var inner_top_1 := _ring_point(inner_radius, h1, a1)
		var outer_top_0 := _ring_point(outer_radius, outer_h0, a0)
		var outer_top_1 := _ring_point(outer_radius, outer_h1, a1)
		var outer_bottom_0 := _ring_point(outer_radius, bottom, a0)
		var outer_bottom_1 := _ring_point(outer_radius, bottom, a1)
		var tint := shade * _random_segment_tint(segment, phase)
		_add_quad(vertices, colors, indices, inner_bottom_0, inner_top_0,
			inner_top_1, inner_bottom_1, tint.darkened(0.16))
		_add_quad(vertices, colors, indices, inner_top_0, outer_top_0,
			outer_top_1, inner_top_1, tint.lightened(0.07))
		_add_quad(vertices, colors, indices, outer_top_0, outer_bottom_0,
			outer_bottom_1, outer_top_1, tint.darkened(0.25))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var ridge := MeshInstance3D.new()
	ridge.name = "Hillside_%02d" % hills.get_child_count()
	ridge.mesh = mesh
	ridge.material_override = _haze_material
	ridge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ridge.extra_cull_margin = 32.0
	hills.add_child(ridge)


func _ridge_height(angle: float, base: float, peak: float, phase: float) -> float:
	var shape := 0.52 + 0.22 * sin(angle * 3.0 + phase) \
		+ 0.15 * sin(angle * 7.0 - phase * 0.7) \
		+ 0.08 * cos(angle * 11.0 + phase)
	return base + peak * clampf(shape, 0.12, 0.98)


func _random_segment_tint(segment: int, phase: float) -> float:
	return 0.88 + 0.12 * (0.5 + 0.5 * sin(float(segment) * 0.82 + phase))


func _ring_point(radius: float, height: float, angle: float) -> Vector3:
	return Vector3(cos(angle) * radius, height, sin(angle) * radius)


func _add_quad(vertices: PackedVector3Array, colors: PackedColorArray,
		indices: PackedInt32Array, a: Vector3, b: Vector3,
		c: Vector3, d: Vector3, color: Color) -> void:
	var start := vertices.size()
	vertices.append_array(PackedVector3Array([a, b, c, d]))
	colors.append_array(PackedColorArray([color, color, color, color]))
	indices.append_array(PackedInt32Array([
		start, start + 1, start + 2,
		start, start + 2, start + 3,
	]))
