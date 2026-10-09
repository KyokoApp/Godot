extends Node3D
## A compact warm flame: layered tongues, upward embers, local light, and velocity-driven lean.

const FIRE_SHADER = preload("res://src/game/realistic_fire.gdshader")
const MAX_SPEED := 5.0

var external_velocity := Vector3.ZERO
var look_camera: Camera3D
var motion_strength := 0.0
var gust_strength := 0.0
var lean_vector := Vector2.ZERO

var _planes: Array[MeshInstance3D] = []
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
	_update_orientation_and_lean(acceleration)
	_update_flame(delta)
	_update_embers()
	_update_light(delta)


func _build_flame_body() -> void:
	_body = Node3D.new()
	_body.name = "FlameBody"
	add_child(_body)
	for index in range(2):
		var material := ShaderMaterial.new()
		material.shader = FIRE_SHADER
		var card := QuadMesh.new()
		card.size = Vector2(0.82, 0.96)
		var plane := MeshInstance3D.new()
		plane.name = "FlameFront" if index == 0 else "FlameCross"
		plane.mesh = card
		plane.material_override = material
		plane.position.y = 0.45
		plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plane.extra_cull_margin = 0.7
		_body.add_child(plane)
		_planes.append(plane)
		_materials.append(material)


func _update_orientation_and_lean(acceleration: Vector3) -> void:
	var camera_right := Vector3.RIGHT
	if is_instance_valid(look_camera):
		camera_right = look_camera.global_transform.basis.x
		camera_right.y = 0.0
		if camera_right.length_squared() > 0.0001:
			camera_right = camera_right.normalized()
	var facing_yaw := atan2(-camera_right.z, camera_right.x)
	var horizontal_velocity := Vector3(_filtered_velocity.x, 0.0, _filtered_velocity.z)
	var travel_direction := Vector3.ZERO
	if horizontal_velocity.length_squared() > 0.0001:
		travel_direction = horizontal_velocity.normalized()
	var wind_back := -travel_direction * motion_strength * 0.34
	wind_back -= Vector3(acceleration.x, 0.0, acceleration.z).limit_length(24.0) / 24.0 * 0.12
	for index in range(_planes.size()):
		var yaw := facing_yaw + float(index) * PI * 0.5
		_planes[index].rotation.y = yaw
		var right := Vector3(cos(yaw), 0.0, -sin(yaw))
		var lean := clampf(wind_back.dot(right), -0.42, 0.42)
		_materials[index].set_shader_parameter("lean", lean)
		_materials[index].set_shader_parameter("heat", motion_strength)
		_materials[index].set_shader_parameter("gust", gust_strength)
		lean_vector = Vector2(wind_back.x, wind_back.z)


func _update_flame(delta: float) -> void:
	var breath := sin(_time * 6.1) * 0.5 + sin(_time * 10.7 + 0.8) * 0.18
	var target_flicker := clampf(0.5 + breath * 0.34 + gust_strength * 0.16, 0.0, 1.0)
	_flicker = lerpf(_flicker, target_flicker, 1.0 - exp(-11.0 * delta))
	for material in _materials:
		material.set_shader_parameter("flicker", _flicker)
	var stretch := Vector3(1.0 - motion_strength * 0.045,
		1.0 + motion_strength * 0.18 + gust_strength * 0.06,
		1.0 - motion_strength * 0.045)
	_body.scale = _body.scale.lerp(stretch, 1.0 - exp(-5.0 * delta))


func _build_embers() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "Embers"
	_particles.amount = 6
	_particles.lifetime = 0.82
	_particles.position.y = 0.28
	_particles.local_coords = false
	_particles.randomness = 0.55
	_particles.fixed_fps = 60
	_particles.interpolate = true
	_particles.visibility_aabb = AABB(Vector3(-0.65, -0.2, -0.65), Vector3(1.3, 1.7, 1.3))
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_particle_material = ParticleProcessMaterial.new()
	_particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_particle_material.emission_sphere_radius = 0.045
	_particle_material.direction = Vector3.UP
	_particle_material.spread = 22.0
	_particle_material.initial_velocity_min = 0.12
	_particle_material.initial_velocity_max = 0.42
	_particle_material.gravity = Vector3(0.0, 0.18, 0.0)
	_particle_material.damping_min = 0.35
	_particle_material.damping_max = 0.7
	_particle_material.scale_min = 0.08
	_particle_material.scale_max = 0.18
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.75))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = scale_curve
	_particle_material.scale_curve = scale_texture
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.34, 1.0])
	colors.colors = PackedColorArray([
		Color(1.0, 0.76, 0.27, 0.95),
		Color(1.0, 0.24, 0.025, 0.78),
		Color(0.32, 0.055, 0.006, 0.0),
	])
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = colors
	_particle_material.color_ramp = color_ramp
	_particles.process_material = _particle_material
	_particles.draw_pass_1 = _make_spark_mesh()
	add_child(_particles)


func _update_embers() -> void:
	var direction := Vector3(-external_velocity.x * 0.16, 1.0, -external_velocity.z * 0.16)
	_particle_material.direction = direction.normalized()
	_particle_material.initial_velocity_min = lerpf(0.12, 0.26, motion_strength)
	_particle_material.initial_velocity_max = lerpf(0.42, 0.72, motion_strength)


func _make_spark_mesh() -> QuadMesh:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = Color(1.0, 0.22, 0.025)
	material.emission_energy_multiplier = 0.45
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var spark := QuadMesh.new()
	spark.size = Vector2(0.045, 0.045)
	spark.material = material
	return spark


func _build_light() -> void:
	_light = OmniLight3D.new()
	_light.name = "FireLight"
	_light.position.y = 0.34
	_light.light_color = Color("ff8735")
	_light.light_energy = 1.12
	_light.omni_range = 2.8
	_light.omni_attenuation = 1.65
	_light.shadow_enabled = false
	add_child(_light)


func _update_light(delta: float) -> void:
	var pulse := sin(_time * 7.2) * 0.08 + sin(_time * 4.1 + 0.5) * 0.045
	var target_energy := 1.08 + pulse + motion_strength * 0.16 + gust_strength * 0.12
	_light.light_energy = lerpf(_light.light_energy, target_energy, 1.0 - exp(-9.0 * delta))
