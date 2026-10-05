extends Node3D
## Satu set-piece Hollow Purple, garis angin ringan, dan satu burst slash/debris.

signal hollow_purple_impact(position: Vector3)

const SLASH_SHADER := preload("res://src/game/world/run_zone_slash.gdshader")

const ORB_RADIUS := 9.5
const CHARGE_TIME := 2.25
const FLIGHT_TIME := 1.05
const AFTERMATH_TIME := 1.35
const WIND_PARTICLES := 32
const IMPACT_PARTICLES := 40

var player: CharacterBody3D
var track: Node3D
var phase := "idle"
var impact_count := 0
var slash_count := 0
var destroyed_rock_count := 0
var _level := 0
var _elapsed := 0.0
var _orb: Node3D
var _shell_material: StandardMaterial3D
var _core_material: StandardMaterial3D
var _ring_materials: Array[StandardMaterial3D] = []
var _rings: Array[MeshInstance3D] = []
var _wave_materials: Array[StandardMaterial3D] = []
var _waves: Array[MeshInstance3D] = []
var _slash_materials: Array[ShaderMaterial] = []
var _slashes: Array[MeshInstance3D] = []
var _wind: GPUParticles3D
var _wind_process: ParticleProcessMaterial
var _burst: GPUParticles3D
var _flight_start := Vector3.ZERO
var _impact_position := Vector3.ZERO


func _ready() -> void:
	name = "RunZoneFX"
	_build_wind()
	_build_impact_burst()
	_build_impact_shapes()


func set_speed_level(level: int) -> void:
	_level = clampi(level, 0, 20)
	if _wind_process != null:
		_wind_process.initial_velocity_min = 1.5 + float(_level) * 0.24
		_wind_process.initial_velocity_max = 4.5 + float(_level) * 0.56
	if _wind != null:
		_wind.emitting = _level > 0


func start_hollow_purple() -> void:
	if phase != "idle" or player == null:
		return
	_build_orb()
	phase = "charging"
	_elapsed = 0.0
	_orb.scale = Vector3.ONE * 0.18
	_orb.global_position = player.global_position + Vector3(0.0, 5.0, -24.0)


func finish() -> void:
	phase = "finished"
	if _wind != null:
		_wind.emitting = false
	if is_instance_valid(_orb):
		_orb.hide()
	if is_instance_valid(_burst):
		_burst.emitting = false
	for ring in _rings:
		ring.hide()
	for wave in _waves:
		wave.hide()
	for slash in _slashes:
		slash.hide()


func _process(delta: float) -> void:
	if player == null:
		return
	if _wind != null:
		_wind.global_position = player.global_position + Vector3(0.0, 1.05, 0.0)
	if phase == "charging":
		_update_charge(delta)
	elif phase == "flight":
		_update_flight(delta)
	elif phase == "aftermath":
		_update_aftermath(delta)


func _build_wind() -> void:
	_wind = GPUParticles3D.new()
	_wind.name = "SpeedWindStreaks"
	_wind.amount = WIND_PARTICLES
	_wind.lifetime = 0.34
	_wind.fixed_fps = 30
	_wind.local_coords = false
	_wind.emitting = false
	_wind.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wind.visibility_aabb = AABB(Vector3(-36.0, -12.0, -44.0), Vector3(72.0, 28.0, 88.0))
	_wind_process = ParticleProcessMaterial.new()
	_wind_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_wind_process.emission_box_extents = Vector3(3.6, 1.0, 6.0)
	_wind_process.direction = Vector3(0.0, 0.0, 1.0)
	_wind_process.spread = 7.0
	_wind_process.gravity = Vector3.ZERO
	_wind_process.damping_min = 0.0
	_wind_process.damping_max = 0.0
	_wind_process.scale_min = 0.62
	_wind_process.scale_max = 1.25
	_wind_process.color_ramp = _wind_gradient()
	_wind.process_material = _wind_process
	_wind.draw_pass_1 = _streak_quad()
	add_child(_wind)
	set_speed_level(0)


func _build_impact_burst() -> void:
	_burst = GPUParticles3D.new()
	_burst.name = "PurpleWindAndRockBurst"
	_burst.amount = IMPACT_PARTICLES
	_burst.lifetime = 0.78
	_burst.one_shot = true
	_burst.explosiveness = 0.96
	_burst.randomness = 0.48
	_burst.local_coords = false
	_burst.emitting = false
	_burst.fixed_fps = 30
	_burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_burst.visibility_aabb = AABB(Vector3(-22.0, -8.0, -22.0), Vector3(44.0, 25.0, 44.0))
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.45
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 155.0
	material.initial_velocity_min = 10.0
	material.initial_velocity_max = 22.0
	material.gravity = Vector3(0.0, -4.8, 0.0)
	material.damping_min = 0.35
	material.damping_max = 1.4
	material.angle_min = -180.0
	material.angle_max = 180.0
	material.scale_min = 0.65
	material.scale_max = 1.65
	material.color_ramp = _impact_gradient()
	_burst.process_material = material
	_burst.draw_pass_1 = _streak_quad()
	add_child(_burst)


func _build_impact_shapes() -> void:
	for index in range(2):
		var torus := TorusMesh.new()
		torus.inner_radius = 0.91
		torus.outer_radius = 1.0
		torus.rings = 8
		torus.ring_segments = 48
		var wave := MeshInstance3D.new()
		wave.name = "PurpleShockwave_%02d" % index
		wave.mesh = torus
		wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var wave_material := _energy_material(Color(0.60, 0.18, 1.0, 0.95), 3.8)
		wave.material_override = wave_material
		wave.hide()
		add_child(wave)
		_waves.append(wave)
		_wave_materials.append(wave_material)

	for index in range(5):
		var quad := QuadMesh.new()
		quad.size = Vector2(13.0 - float(index % 2) * 2.0, 0.24)
		var slash := MeshInstance3D.new()
		slash.name = "HollowPurpleSlash_%02d" % index
		slash.mesh = quad
		slash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = SLASH_SHADER
		material.set_shader_parameter("tint", Color(0.72, 0.45, 1.0, 1.0)
			if index % 2 == 0 else Color(0.96, 0.86, 1.0, 1.0))
		material.set_shader_parameter("opacity", 0.0)
		slash.material_override = material
		slash.hide()
		add_child(slash)
		_slashes.append(slash)
		_slash_materials.append(material)


func _build_orb() -> void:
	if is_instance_valid(_orb):
		return
	_orb = Node3D.new()
	_orb.name = "HollowPurpleSphere"
	add_child(_orb)

	var shell := MeshInstance3D.new()
	shell.name = "TranslucentPurpleShell"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 40
	sphere.rings = 28
	shell.mesh = sphere
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shell_material = StandardMaterial3D.new()
	_shell_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shell_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shell_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shell_material.albedo_color = Color(0.82, 0.36, 1.0, 1.0)
	_shell_material.emission_enabled = true
	_shell_material.emission = Color(1.0, 0.76, 1.0)
	_shell_material.emission_energy_multiplier = 6.0
	shell.material_override = _shell_material
	_orb.add_child(shell)

	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.30
	core_mesh.height = 0.60
	core_mesh.radial_segments = 32
	core_mesh.rings = 20
	var core := MeshInstance3D.new()
	core.name = "HollowVoidCore"
	core.mesh = core_mesh
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_core_material = StandardMaterial3D.new()
	_core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core_material.albedo_color = Color(0.012, 0.004, 0.03, 1.0)
	_core_material.emission_enabled = true
	_core_material.emission = Color(0.075, 0.008, 0.19)
	_core_material.emission_energy_multiplier = 0.65
	core.material_override = _core_material
	_orb.add_child(core)

	for index in range(3):
		var torus := TorusMesh.new()
		torus.inner_radius = 0.82
		torus.outer_radius = 0.91
		torus.rings = 8
		torus.ring_segments = 48
		var ring := MeshInstance3D.new()
		ring.name = "VioletOrbit_%02d" % index
		ring.mesh = torus
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var color := Color(0.84, 0.48, 1.0, 0.94) if index != 1 \
			else Color(0.40, 0.13, 0.95, 0.94)
		var material := _energy_material(color, 4.8)
		ring.material_override = material
		ring.rotation = Vector3(float(index) * 0.74, float(index) * 1.05,
			float(index) * 0.42)
		_orb.add_child(ring)
		_ring_materials.append(material)
		_rings.append(ring)


func _update_charge(delta: float) -> void:
	_elapsed += delta
	var growth := clampf(_elapsed / 1.05, 0.0, 1.0)
	var pulse := 1.0 + 0.045 * sin(_elapsed * 9.0)
	_orb.scale = Vector3.ONE * lerpf(0.18, ORB_RADIUS, smoothstep(0.0, 1.0, growth)) * pulse
	_orb.global_position = player.global_position + Vector3(0.0,
		5.0 + 0.22 * sin(_elapsed * 3.6), -24.0)
	_orb.rotation.y += delta * 0.75
	_orb.rotation.z += delta * 0.31
	for index in range(_rings.size()):
		_rings[index].rotation.y += delta * (1.5 if index % 2 == 0 else -1.2)
	if _elapsed >= CHARGE_TIME:
		phase = "flight"
		_elapsed = 0.0
		_flight_start = _orb.global_position


func _update_flight(delta: float) -> void:
	_elapsed += delta
	var progress := clampf(_elapsed / FLIGHT_TIME, 0.0, 1.0)
	var eased := progress * progress * (3.0 - 2.0 * progress)
	# Jangan tarik bola kembali ke dekat kamera: bola harus tetap melaju
	# di depan pelari supaya charge dan impact sama-sama masuk frame.
	var target := player.global_position + Vector3(0.0, 6.0, -30.0)
	_orb.global_position = _flight_start.lerp(target, eased)
	_orb.rotation.y += delta * 3.8
	_orb.scale = Vector3.ONE * ORB_RADIUS * (1.0 + 0.055 * sin(_elapsed * 18.0))
	if progress >= 1.0:
		_start_impact()


func _start_impact() -> void:
	phase = "aftermath"
	_elapsed = 0.0
	impact_count += 1
	_impact_position = Vector3(_orb.global_position.x, 0.0, _orb.global_position.z)
	if track != null and track.has_method("destroy_area"):
		track.call("destroy_area", _impact_position.z, 18.0)
		destroyed_rock_count = int(track.get("destroyed_rock_count"))
	_wind.emitting = false
	_burst.global_position = _impact_position + Vector3(0.0, 1.0, 0.0)
	_burst.emitting = true
	_burst.restart()
	for index in range(_waves.size()):
		_waves[index].global_position = _impact_position + Vector3(0.0, 0.07 + float(index) * 0.025, 0.0)
		_waves[index].scale = Vector3.ONE * 0.18
		_waves[index].show()
		_wave_materials[index].albedo_color = Color(0.68, 0.24, 1.0, 0.95)
	for index in range(_slashes.size()):
		var slash := _slashes[index]
		slash.global_position = _impact_position + Vector3(0.0, 1.0 + float(index % 3) * 0.85, 0.0)
		slash.rotation = Vector3(0.0, float(index) * 0.62, -0.42 + float(index % 3) * 0.42)
		slash.scale = Vector3(0.12, 0.75, 1.0)
		slash.show()
		_slash_materials[index].set_shader_parameter("opacity", 1.0)
	slash_count = _slashes.size()
	hollow_purple_impact.emit(_impact_position)


func _update_aftermath(delta: float) -> void:
	_elapsed += delta
	var wave_progress := clampf(_elapsed / 0.95, 0.0, 1.0)
	for index in range(_waves.size()):
		_waves[index].scale = Vector3.ONE * lerpf(0.18, 13.0, wave_progress)
		_wave_materials[index].albedo_color = Color(0.68, 0.24, 1.0,
			0.95 * (1.0 - wave_progress))
	var slash_fade := 1.0 - clampf(_elapsed / 0.7, 0.0, 1.0)
	for index in range(_slashes.size()):
		_slashes[index].scale.x = lerpf(0.12, 1.0, minf(_elapsed / 0.11, 1.0))
		_slash_materials[index].set_shader_parameter("opacity", slash_fade)
	var orb_fade := 1.0 - clampf(_elapsed / 0.45, 0.0, 1.0)
	_shell_material.albedo_color.a = orb_fade
	_core_material.albedo_color = Color(0.012, 0.004, 0.03, orb_fade)
	for material in _ring_materials:
		material.albedo_color.a = 0.94 * orb_fade
	_orb.scale = Vector3.ONE * ORB_RADIUS * (1.0 + 0.18 * minf(_elapsed / 0.18, 1.0))
	if _elapsed >= AFTERMATH_TIME:
		phase = "finished"
		_orb.hide()
		for wave in _waves:
			wave.hide()
		for slash in _slashes:
			slash.hide()


func _energy_material(color: Color, glow: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = glow
	return material


func _streak_quad() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.075, 1.45)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = Color(0.78, 0.47, 1.0)
	material.emission_energy_multiplier = 1.7
	quad.material = material
	return quad


func _wind_gradient() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.72, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.92, 0.76, 1.0, 0.0), Color(0.82, 0.56, 1.0, 0.75),
		Color(0.61, 0.32, 0.94, 0.48), Color(0.31, 0.16, 0.54, 0.0),
	])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


func _impact_gradient() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.13, 0.48, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 0.94, 1.0, 1.0), Color(0.82, 0.45, 1.0, 0.98),
		Color(0.45, 0.17, 0.83, 0.75), Color(0.12, 0.045, 0.24, 0.0),
	])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture
