extends Node3D
## Pet-only tapered flame; archived combat core/shell remain unchanged.
## Anchor diatur controller pet baru; tidak membawa sistem combat lama.

const FLAME = preload("res://src/game/legacy_spirit/pet_flame.gdshader")

var external_velocity := Vector3.ZERO
var _shell: ShaderMaterial
var _time := 0.0
var _pulse := 0.0
var _trail := Vector3.ZERO


func _ready() -> void:
	name = "LegacyFireSpirit"
	_shell = ShaderMaterial.new()
	_shell.shader = FLAME
	var flame := MeshInstance3D.new()
	flame.name = "FireTongues"
	var card := QuadMesh.new()
	card.size = Vector2(0.58, 0.78)
	flame.mesh = card
	flame.material_override = _shell
	flame.position.y = 0.22
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.extra_cull_margin = 0.5
	add_child(flame)
	var halo := MeshInstance3D.new()
	halo.name = "SoftHalo"
	halo.mesh = _quad(0.24, Color(0.45, 0.35, 1.0, 0.16), false)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	_build_embers()


func pulse() -> void:
	_pulse = 1.0


func _process(delta: float) -> void:
	_time += delta
	_pulse = maxf(_pulse - delta * 2.6, 0.0)
	position = Vector3(sin(_time * 1.3 + 0.4) * 0.018,
		sin(_time * 1.7) * 0.018 + sin(_time * 3.1 + 1.2) * 0.007,
		cos(_time * 1.05 + 2.1) * 0.015)
	rotation = Vector3(sin(_time * 1.9 + 0.7) * 0.06,
		sin(_time * 0.6) * 0.4, cos(_time * 1.4 + 1.5) * 0.06)
	scale = Vector3.ONE * (1.0 + sin(_time * 5.0) * 0.035 + _pulse * 0.3)
	var target := (-external_velocity * 0.018).limit_length(0.20)
	_trail = _trail.lerp(target, 1.0 - exp(-9.0 * delta))
	_shell.set_shader_parameter("trail", _trail)
	_shell.set_shader_parameter("pulse", _pulse)


func _quad(size: float, tint: Color, particles: bool) -> QuadMesh:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, 0.15, 1])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = (BaseMaterial3D.BILLBOARD_PARTICLES if particles
		else BaseMaterial3D.BILLBOARD_ENABLED)
	mat.vertex_color_use_as_albedo = particles
	mat.albedo_texture = texture
	mat.albedo_color = tint
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.disable_receive_shadows = true
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * size
	quad.material = mat
	return quad


func _build_embers() -> void:
	var embers := GPUParticles3D.new()
	embers.name = "SpiritEmbers"
	embers.amount = 5
	embers.lifetime = 0.9
	embers.position.y = 0.18
	embers.local_coords = false
	embers.randomness = 0.5
	embers.fixed_fps = 60
	embers.interpolate = true
	embers.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 3, 2))
	embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 0.05
	material.direction = Vector3.UP
	material.spread = 35.0
	material.initial_velocity_min = 0.25
	material.initial_velocity_max = 0.50
	material.gravity = Vector3(0, 0.3, 0)
	material.damping_min = 0.3
	material.damping_max = 0.7
	material.scale_min = 0.18
	material.scale_max = 0.38
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = curve
	material.scale_curve = scale_texture
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, 0.4, 1])
	gradient.colors = PackedColorArray([Color(1.6, 1.1, 2.4),
		Color(0.55, 0.35, 1.0), Color(0.3, 0.15, 0.5, 0)])
	var colors := GradientTexture1D.new()
	colors.gradient = gradient
	material.color_ramp = colors
	embers.process_material = material
	embers.draw_pass_1 = _quad(0.035, Color.WHITE, true)
	add_child(embers)
