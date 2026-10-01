extends Node3D
## A bright hit/guard burst: star flash, expanding ring, sparks, and damage callout.

const DURATION := 0.56
const SPARK_LIFETIME := 0.42

var age := 0.0
var effect_tint := Color(0.38, 0.82, 1.0)
var damage := 0
var heavy := false
var label_text := ""
var _materials: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []
var _base_energy: Array[float] = []
var _ring: MeshInstance3D
var _core: MeshInstance3D
var _star: MeshInstance3D
var _light: OmniLight3D
var _sparks: GPUParticles3D
var _number: Label3D


func configure(origin: Vector3, facing: Vector3, tint: Color, hit_damage: int,
		is_heavy: bool, callout: String) -> void:
	global_position = origin
	effect_tint = tint
	damage = hit_damage
	heavy = is_heavy
	label_text = callout
	var direction := facing
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	look_at(global_position + direction.normalized(), Vector3.UP)
	_build_flash()
	_build_particles()
	_build_callout()


func _build_flash() -> void:
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.22 if not heavy else 0.28
	ring_mesh.outer_radius = 0.30 if not heavy else 0.38
	ring_mesh.rings = 8
	ring_mesh.ring_segments = 20
	_ring = MeshInstance3D.new()
	_ring.name = "HitRing"
	_ring.mesh = ring_mesh
	_ring.rotation.x = PI * 0.5
	_ring.position.z = -0.04
	_set_material(_ring, effect_tint, 1.9, 0.78)
	add_child(_ring)

	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.18 if not heavy else 0.25
	sphere_mesh.height = sphere_mesh.radius * 2.0
	sphere_mesh.radial_segments = 16
	sphere_mesh.rings = 8
	_core = MeshInstance3D.new()
	_core.name = "HitCore"
	_core.mesh = sphere_mesh
	_core.position.z = -0.08
	_set_material(_core, Color.WHITE, 3.2, 0.88)
	add_child(_core)

	_star = MeshInstance3D.new()
	_star.name = "HitStar"
	_star.mesh = _make_star()
	_star.position.z = -0.12
	_set_material(_star, effect_tint, 2.8, 0.80)
	add_child(_star)

	_light = OmniLight3D.new()
	_light.name = "HitFlash"
	_light.light_color = effect_tint
	_light.omni_range = 3.8 if not heavy else 5.2
	_light.light_energy = 2.8 if not heavy else 4.2
	_light.position.z = -0.12
	_light.shadow_enabled = false
	add_child(_light)


func _make_star() -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		var next_angle := TAU * float((index + 1) % 16) / 16.0
		var radius := 0.86 if index % 4 == 0 else (0.52 if index % 2 == 0 else 0.16)
		var next_radius := 0.86 if (index + 1) % 4 == 0 else (
			0.52 if (index + 1) % 2 == 0 else 0.16)
		var point := Vector3(cos(angle) * radius, sin(angle) * radius, 0.0)
		var next_point := Vector3(cos(next_angle) * next_radius,
			sin(next_angle) * next_radius, 0.0)
		mesh.surface_set_normal(Vector3.BACK)
		mesh.surface_set_color(Color.WHITE)
		mesh.surface_add_vertex(Vector3.ZERO)
		mesh.surface_set_color(Color.WHITE)
		mesh.surface_add_vertex(point)
		mesh.surface_set_color(Color.WHITE)
		mesh.surface_add_vertex(next_point)
	mesh.surface_end()
	return mesh


func _set_material(mesh: MeshInstance3D, tint: Color, energy: float,
		alpha: float) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = energy
	material.disable_receive_shadows = true
	material.disable_ambient_light = true
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_materials.append(material)
	_base_colors.append(material.albedo_color)
	_base_energy.append(energy)


func _build_particles() -> void:
	_sparks = GPUParticles3D.new()
	_sparks.name = "ImpactSparks"
	_sparks.amount = 14 if not heavy else 22
	_sparks.lifetime = SPARK_LIFETIME
	_sparks.one_shot = true
	_sparks.explosiveness = 0.96
	_sparks.randomness = 0.22
	_sparks.local_coords = true
	_sparks.fixed_fps = 30
	_sparks.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process_material.emission_sphere_radius = 0.09
	process_material.direction = Vector3(0.0, 0.12, 1.0)
	process_material.spread = 180.0
	process_material.initial_velocity_min = 1.5 if not heavy else 2.2
	process_material.initial_velocity_max = 4.2 if not heavy else 6.0
	process_material.gravity = Vector3(0.0, -2.2, 0.0)
	process_material.damping_min = 0.8
	process_material.damping_max = 1.8
	process_material.scale_min = 0.65
	process_material.scale_max = 1.2
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 1.0])
	gradient.colors = PackedColorArray([
		Color.WHITE,
		Color(effect_tint.r, effect_tint.g, effect_tint.b, 0.92),
		Color(effect_tint.r, effect_tint.g, effect_tint.b, 0.0),
	])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process_material.color_ramp = ramp
	_sparks.process_material = process_material
	var spark_material := StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	spark_material.vertex_color_use_as_albedo = true
	spark_material.albedo_color = Color.WHITE
	spark_material.disable_receive_shadows = true
	var spark_mesh := QuadMesh.new()
	spark_mesh.size = Vector2(0.055, 0.18)
	spark_mesh.material = spark_material
	_sparks.draw_pass_1 = spark_mesh
	add_child(_sparks)
	_sparks.emitting = true


func _build_callout() -> void:
	var text := label_text
	if text.is_empty() and damage > 0:
		text = "%d%s" % [damage, "!" if heavy else ""]
	if text.is_empty():
		return
	_number = Label3D.new()
	_number.name = "DamageCallout"
	_number.text = text
	_number.font_size = 48 if not heavy else 56
	_number.pixel_size = 0.005
	_number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_number.no_depth_test = true
	_number.outline_size = 8
	_number.outline_modulate = Color(0.025, 0.035, 0.09, 0.95)
	_number.modulate = Color(1.0, 0.94, 0.70, 1.0) if heavy else Color.WHITE
	_number.position = Vector3(0.0, 0.46, 0.0)
	add_child(_number)


func _process(delta: float) -> void:
	age += delta
	var progress := clampf(age / DURATION, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - progress, 2.0)
	var fade := pow(1.0 - progress, 1.8)
	_ring.scale = Vector3.ONE * lerpf(0.40, 2.25 if heavy else 1.85, eased)
	_core.scale = Vector3.ONE * lerpf(0.18, 0.72 if heavy else 0.54, eased)
	_star.scale = Vector3.ONE * lerpf(0.30, 1.14 if heavy else 0.92, eased)
	_star.rotation.z = lerpf(-0.18, 0.42, progress)
	for index in range(_materials.size()):
		var color: Color = _base_colors[index]
		color.a *= fade
		_materials[index].albedo_color = color
		_materials[index].emission_energy_multiplier = _base_energy[index] * fade
	if _light != null:
		_light.light_energy = (4.2 if heavy else 2.8) * fade
	if _number != null:
		_number.position.y = 0.46 + progress * 0.62
		var text_color: Color = _number.modulate
		text_color.a = 1.0 - progress
		_number.modulate = text_color
	if progress >= 1.0:
		queue_free()
