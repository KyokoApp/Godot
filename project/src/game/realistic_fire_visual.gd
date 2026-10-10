extends Node3D
## A small, genuinely 3D flame with a firefly-blue light and a gentle hover bob.

const FIRE_SHADER = preload("res://src/game/realistic_fire.gdshader")
const MAX_SPEED := 5.0
const FLAME_HEIGHT := 0.62
const BOB_AMPLITUDE := 0.11
const BOB_SPEED := 2.8
const RING_COUNT := 9
const SEGMENT_COUNT := 18

var external_velocity := Vector3.ZERO
var motion_strength := 0.0
var gust_strength := 0.0
var lean_vector := Vector2.ZERO
var flame_height := FLAME_HEIGHT
var bob_offset := 0.0

var _flames: Array[MeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _body: Node3D
var _light: OmniLight3D
var _particles: GPUParticles3D
var _particle_material: ParticleProcessMaterial
var _filtered_velocity := Vector3.ZERO
var _previous_velocity := Vector3.ZERO
var _time := 0.0
var _flicker := 0.5


func _ready() -> void:
	name = "FireVisual"
	_build_flame_body()
	_build_embers()
	_build_light()


func _process(delta: float) -> void:
	_time += delta
	var response := 1.0 - exp(-8.0 * delta)
	_filtered_velocity = _filtered_velocity.lerp(external_velocity, response)
	var acceleration := (external_velocity - _previous_velocity) / maxf(delta, 0.001)
	_previous_velocity = external_velocity
	motion_strength = clampf(_filtered_velocity.length() / MAX_SPEED, 0.0, 1.0)
	var horizontal_acceleration := Vector2(acceleration.x, acceleration.z).length()
	var acceleration_amount := clampf(horizontal_acceleration / 24.0, 0.0, 1.0)
	gust_strength = lerpf(gust_strength, acceleration_amount, 1.0 - exp(-6.0 * delta))
	_update_orientation_and_lean(acceleration, delta)
	_update_flame(delta)
	_update_embers()
	_update_light(delta)


func flame_center_position() -> Vector3:
	return _body.to_global(Vector3(0.0, FLAME_HEIGHT * 0.5, 0.0))


func _build_flame_body() -> void:
	_body = Node3D.new()
	_body.name = "FlameBody"
	add_child(_body)
	_add_flame_lobe("OuterFlame", FLAME_HEIGHT, 0.19, Vector3.ZERO, 0.0, 0.0)
	_add_flame_lobe("InnerFlame", FLAME_HEIGHT * 0.70, 0.105,
		Vector3(0.008, 0.025, 0.006), 1.7, 1.0)


func _add_flame_lobe(
	lobe_name: String, height: float, radius: float, offset: Vector3,
	seed: float, core: float
) -> void:
	var material := ShaderMaterial.new()
	material.shader = FIRE_SHADER
	material.set_shader_parameter("lean", 0.0)
	material.set_shader_parameter("heat", 0.0)
	material.set_shader_parameter("gust", 0.0)
	material.set_shader_parameter("flicker", _flicker)
	material.set_shader_parameter("seed", seed)
	material.set_shader_parameter("core", core)
	var flame := MeshInstance3D.new()
	flame.name = lobe_name
	flame.mesh = _make_flame_mesh(height, radius, seed)
	flame.material_override = material
	flame.position = offset
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.extra_cull_margin = 0.8
	_body.add_child(flame)
	_flames.append(flame)
	_materials.append(material)


func _make_flame_mesh(height: float, radius: float, seed: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(RING_COUNT - 1):
		var lower := float(ring) / float(RING_COUNT - 1)
		var upper := float(ring + 1) / float(RING_COUNT - 1)
		for segment in range(SEGMENT_COUNT):
			var around0 := float(segment) / float(SEGMENT_COUNT)
			var around1 := float(segment + 1) / float(SEGMENT_COUNT)
			var p00 := _flame_vertex(lower, around0, height, radius, seed)
			var p01 := _flame_vertex(lower, around1, height, radius, seed)
			var p10 := _flame_vertex(upper, around0, height, radius, seed)
			var p11 := _flame_vertex(upper, around1, height, radius, seed)
			_append_flame_vertex(surface, p00, Vector2(around0, lower))
			_append_flame_vertex(surface, p10, Vector2(around0, upper))
			_append_flame_vertex(surface, p01, Vector2(around1, lower))
			_append_flame_vertex(surface, p01, Vector2(around1, lower))
			_append_flame_vertex(surface, p10, Vector2(around0, upper))
			_append_flame_vertex(surface, p11, Vector2(around1, upper))
	surface.index()
	surface.generate_normals()
	return surface.commit()


func _flame_vertex(
	height_fraction: float, around: float, height: float, radius: float, seed: float
) -> Vector3:
	var angle := around * TAU
	var taper := 0.025 + 0.975 * pow(maxf(0.0, 1.0 - height_fraction), 0.78)
	var belly := 0.34 + 0.66 * sin(PI * height_fraction)
	var variation := 1.0 + 0.10 * sin(angle * 3.0 + seed) \
		+ 0.055 * cos(angle * 5.0 - seed * 0.7)
	var ring_radius := radius * taper * belly * variation
	var bend := height_fraction * height_fraction
	var center_x := sin(height_fraction * 2.7 + seed) * 0.035 * bend
	var center_z := cos(height_fraction * 2.3 + seed * 0.8) * 0.025 * bend
	return Vector3(
		cos(angle) * ring_radius + center_x,
		height_fraction * height,
		sin(angle) * ring_radius + center_z)


func _append_flame_vertex(surface: SurfaceTool, point: Vector3, uv: Vector2) -> void:
	surface.set_uv(uv)
	surface.add_vertex(point)


func _update_orientation_and_lean(acceleration: Vector3, delta: float) -> void:
	var horizontal_velocity := Vector3(_filtered_velocity.x, 0.0, _filtered_velocity.z)
	var travel_direction := Vector3.ZERO
	if horizontal_velocity.length_squared() > 0.0001:
		travel_direction = horizontal_velocity.normalized()
	var wind_back := -travel_direction * motion_strength * 0.34
	wind_back -= Vector3(acceleration.x, 0.0, acceleration.z).limit_length(24.0) / 24.0 * 0.12
	var lean := minf(wind_back.length(), 0.42)
	if _body != null and wind_back.length_squared() > 0.0001:
		var target_yaw := atan2(-wind_back.z, wind_back.x)
		_body.rotation.y = lerp_angle(_body.rotation.y, target_yaw, 1.0 - exp(-5.0 * delta))
	for material in _materials:
		material.set_shader_parameter("lean", lean)
		material.set_shader_parameter("heat", motion_strength)
		material.set_shader_parameter("gust", gust_strength)
	lean_vector = Vector2(wind_back.x, wind_back.z)


func _update_flame(delta: float) -> void:
	var breath := sin(_time * 6.1) * 0.5 + sin(_time * 10.7 + 0.8) * 0.18
	var target_flicker := clampf(0.5 + breath * 0.34 + gust_strength * 0.16, 0.0, 1.0)
	_flicker = lerpf(_flicker, target_flicker, 1.0 - exp(-11.0 * delta))
	bob_offset = sin(_time * BOB_SPEED) * BOB_AMPLITUDE
	position.y = bob_offset
	for material in _materials:
		material.set_shader_parameter("flicker", _flicker)
	var stretch := Vector3(1.0 - motion_strength * 0.08,
		1.0 + motion_strength * 0.12 + gust_strength * 0.05,
		1.0 - motion_strength * 0.08)
	_body.scale = _body.scale.lerp(stretch, 1.0 - exp(-5.0 * delta))


func _build_embers() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "Embers"
	_particles.amount = 4
	_particles.lifetime = 0.72
	_particles.position.y = 0.22
	_particles.local_coords = false
	_particles.randomness = 0.55
	_particles.fixed_fps = 60
	_particles.interpolate = true
	_particles.visibility_aabb = AABB(Vector3(-0.38, -0.12, -0.38), Vector3(0.76, 1.0, 0.76))
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_particle_material = ParticleProcessMaterial.new()
	_particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_particle_material.emission_sphere_radius = 0.025
	_particle_material.direction = Vector3.UP
	_particle_material.spread = 18.0
	_particle_material.initial_velocity_min = 0.08
	_particle_material.initial_velocity_max = 0.24
	_particle_material.gravity = Vector3(0.0, 0.08, 0.0)
	_particle_material.damping_min = 0.25
	_particle_material.damping_max = 0.55
	_particle_material.scale_min = 0.06
	_particle_material.scale_max = 0.13
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.75))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = scale_curve
	_particle_material.scale_curve = scale_texture
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.38, 1.0])
	colors.colors = PackedColorArray([
		Color(0.48, 0.88, 1.0, 0.9),
		Color(0.12, 0.48, 1.0, 0.64),
		Color(0.035, 0.13, 0.42, 0.0),
	])
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = colors
	_particle_material.color_ramp = color_ramp
	_particles.process_material = _particle_material
	_particles.draw_pass_1 = _make_spark_mesh()
	add_child(_particles)


func _update_embers() -> void:
	var direction := Vector3(-external_velocity.x * 0.10, 1.0, -external_velocity.z * 0.10)
	_particle_material.direction = direction.normalized()
	_particle_material.initial_velocity_min = lerpf(0.08, 0.14, motion_strength)
	_particle_material.initial_velocity_max = lerpf(0.24, 0.38, motion_strength)


func _make_spark_mesh() -> QuadMesh:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = Color("75caff")
	material.emission_energy_multiplier = 0.55
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var spark := QuadMesh.new()
	spark.size = Vector2(0.035, 0.035)
	spark.material = material
	return spark


func _build_light() -> void:
	_light = OmniLight3D.new()
	_light.name = "FireLight"
	_light.position.y = 0.22
	_light.light_color = Color("75caff")
	_light.light_energy = 0.82
	_light.omni_range = 2.1
	_light.omni_attenuation = 1.75
	_light.shadow_enabled = false
	add_child(_light)


func _update_light(delta: float) -> void:
	var pulse := sin(_time * 4.7) * 0.07 + sin(_time * 2.2 + 0.5) * 0.035
	var target_energy := 0.80 + pulse + motion_strength * 0.08 + gust_strength * 0.05
	_light.light_energy = lerpf(_light.light_energy, target_energy, 1.0 - exp(-8.0 * delta))
