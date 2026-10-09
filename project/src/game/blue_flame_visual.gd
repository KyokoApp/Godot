extends Node3D
## Kobaran api biru kecil sebagai seluruh visual player—tanpa rig atau mesh tubuh.

const FLAME_SHADER = preload("res://src/game/blue_flame.gdshader")

var external_velocity := Vector3.ZERO

var _flame_material: ShaderMaterial
var _flame_mesh: MeshInstance3D
var _light: OmniLight3D
var _time := 0.0
var _trail := Vector3.ZERO


func _ready() -> void:
	name = "BlueFlameVisual"
	_build_flame()
	_build_halo()
	_build_embers()
	_build_light()


func _process(delta: float) -> void:
	_time += delta
	var trail_target := (-external_velocity * 0.018).limit_length(0.20)
	_trail = _trail.lerp(trail_target, 1.0 - exp(-9.0 * delta))
	_flame_material.set_shader_parameter("trail", _trail)
	_flame_material.set_shader_parameter("glow", 0.5 + sin(_time * 4.8) * 0.5)
	_flame_mesh.scale = Vector3(
		1.0 + sin(_time * 5.1) * 0.035,
		1.0 + sin(_time * 4.2 + 0.7) * 0.045,
		1.0)
	if _light != null:
		_light.light_energy = 1.15 + sin(_time * 4.8) * 0.16


func _build_flame() -> void:
	_flame_material = ShaderMaterial.new()
	_flame_material.shader = FLAME_SHADER
	var card := QuadMesh.new()
	card.size = Vector2(0.46, 0.64)
	_flame_mesh = MeshInstance3D.new()
	_flame_mesh.name = "Flame"
	_flame_mesh.mesh = card
	_flame_mesh.material_override = _flame_material
	_flame_mesh.position.y = 0.32
	_flame_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame_mesh.extra_cull_margin = 0.5
	add_child(_flame_mesh)


func _build_halo() -> void:
	var aura := MeshInstance3D.new()
	aura.name = "BlueAura"
	aura.mesh = _radial_quad(0.72, Color(0.12, 0.50, 1.0, 0.22), true)
	aura.position.y = 0.34
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(aura)

	# Pendar lembut menyentuh tanah tepat di bawah nyala api.
	var ground_glow := MeshInstance3D.new()
	ground_glow.name = "GroundGlow"
	ground_glow.mesh = _radial_quad(1.05, Color(0.10, 0.42, 1.0, 0.24), false)
	ground_glow.rotation.x = -PI * 0.5
	ground_glow.position.y = -0.21
	ground_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground_glow)


func _build_embers() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "BlueEmbers"
	particles.amount = 7
	particles.lifetime = 0.9
	particles.position.y = 0.30
	particles.local_coords = true
	particles.randomness = 0.45
	particles.fixed_fps = 60
	particles.interpolate = true
	particles.visibility_aabb = AABB(Vector3(-0.7, -0.3, -0.7), Vector3(1.4, 1.6, 1.4))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	motion.emission_sphere_radius = 0.06
	motion.direction = Vector3(0.0, 1.0, 0.0)
	motion.spread = 28.0
	motion.initial_velocity_min = 0.22
	motion.initial_velocity_max = 0.48
	motion.gravity = Vector3(0.0, 0.22, 0.0)
	motion.damping_min = 0.3
	motion.damping_max = 0.7
	motion.scale_min = 0.12
	motion.scale_max = 0.30
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = scale_curve
	motion.scale_curve = scale_texture
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
	colors.colors = PackedColorArray([
		Color(0.60, 0.90, 1.25, 1.0),
		Color(0.10, 0.48, 1.0, 0.9),
		Color(0.02, 0.12, 0.72, 0.0),
	])
	var color_ramp := GradientTexture1D.new()
	color_ramp.gradient = colors
	motion.color_ramp = color_ramp
	particles.process_material = motion
	particles.draw_pass_1 = _radial_quad(0.08, Color.WHITE, false, true)
	add_child(particles)


func _build_light() -> void:
	_light = OmniLight3D.new()
	_light.name = "BlueFlameLight"
	_light.position.y = 0.32
	_light.light_color = Color(0.12, 0.48, 1.0)
	_light.light_energy = 1.15
	_light.omni_range = 3.8
	_light.omni_attenuation = 1.45
	_light.shadow_enabled = false
	add_child(_light)


func _radial_quad(size: float, tint: Color, billboard: bool, particles := false) -> QuadMesh:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.18, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.88),
		Color(1.0, 1.0, 1.0, 0.48),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if particles:
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	else:
		material.billboard_mode = (BaseMaterial3D.BILLBOARD_ENABLED if billboard
			else BaseMaterial3D.BILLBOARD_DISABLED)
	material.vertex_color_use_as_albedo = particles
	material.albedo_texture = texture
	material.albedo_color = tint
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.disable_receive_shadows = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = material
	return quad
