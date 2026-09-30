extends RefCounted
## Resource bersama: core/shell archive + billboard api GDQuest (MIT).

const CORE = preload("res://src/game/legacy_spirit/fireball_core.gdshader")
const SHELL = preload("res://src/game/legacy_spirit/fireball_shell.gdshader")
const FLAME = preload("res://src/game/attack_fx/flame_particles.gdshader")

static var _flame: ShaderMaterial
static var _spark: StandardMaterial3D


static func sphere(radius: float, shader: Shader, intensity: float) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 22
	mesh.rings = 11
	visual.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("intensity", intensity)
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.extra_cull_margin = 3.0
	return visual


static func _flame_material() -> ShaderMaterial:
	if _flame != null:
		return _flame
	_flame = ShaderMaterial.new()
	_flame.shader = FLAME
	var noise := FastNoiseLite.new()
	noise.seed = 5523
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.09
	noise.fractal_octaves = 3
	var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
	for y in range(64):
		for x in range(64):
			var top := lerpf(noise.get_noise_2d(x, y), noise.get_noise_2d(x - 64, y), x / 64.0)
			var bottom := lerpf(noise.get_noise_2d(x, y - 64),
				noise.get_noise_2d(x - 64, y - 64), x / 64.0)
			var value := lerpf(top, bottom, y / 64.0) * 0.5 + 0.5
			image.set_pixel(x, y, Color(value, value, value))
	_flame.set_shader_parameter("noise_texture", ImageTexture.create_from_image(image))
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color.BLACK])
	var mask := GradientTexture2D.new()
	mask.gradient = gradient
	mask.width = 64
	mask.height = 64
	mask.fill = GradientTexture2D.FILL_RADIAL
	mask.fill_from = Vector2(0.5, 0.5)
	mask.fill_to = Vector2(0.5, 0)
	_flame.set_shader_parameter("texture_mask", mask)
	_flame.set_shader_parameter("texture_scale", Vector2(2.4, 2.4))
	_flame.set_shader_parameter("time_scale", 2.0)
	return _flame


static func _spark_material() -> StandardMaterial3D:
	if _spark != null:
		return _spark
	_spark = StandardMaterial3D.new()
	_spark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_spark.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_spark.vertex_color_use_as_albedo = true
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0)
	_spark.albedo_texture = texture
	_spark.disable_receive_shadows = true
	return _spark


static func particles(label: String, count: int, life: float, burst: bool,
		flame: bool) -> GPUParticles3D:
	var emitter := GPUParticles3D.new()
	emitter.name = label
	emitter.amount = count
	emitter.lifetime = life
	emitter.one_shot = burst
	emitter.explosiveness = 0.95 if burst else 0.0
	emitter.randomness = 0.35
	emitter.local_coords = false
	emitter.fixed_fps = 30
	emitter.interpolate = true
	emitter.visibility_aabb = AABB(Vector3(-10, -4, -10), Vector3(20, 16, 20))
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.15 if burst else 0.04
	process.direction = Vector3.UP
	process.spread = 85.0 if burst else 180.0
	process.initial_velocity_min = 2.2 if burst else 0.05
	process.initial_velocity_max = (5.5 if flame else 8.0) if burst else 0.6
	process.gravity = Vector3(0, 0.6 if flame else -6.0, 0)
	process.damping_min = 2.0 if flame else 0.2
	process.damping_max = 4.0 if flame else 0.6
	process.angle_min = -180
	process.angle_max = 180
	process.scale_min = 0.6
	process.scale_max = 1.1
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.5 if flame else 1.0))
	curve.add_point(Vector2(0.15, 1.0))
	curve.add_point(Vector2(1, 0))
	var scale_texture := CurveTexture.new()
	scale_texture.curve = curve
	process.scale_curve = scale_texture
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, 0.15, 0.60, 1])
	gradient.colors = PackedColorArray([Color(0.8, 0.94, 1, 1), Color(0.4, 0.7, 1, 1),
		Color(0.58, 0.28, 0.9, 0.7), Color(0.15, 0.07, 0.30, 0)])
	var color_texture := GradientTexture1D.new()
	color_texture.gradient = gradient
	process.color_ramp = color_texture
	emitter.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.85, 1.20) if flame else Vector2(0.035, 0.16)
	if not burst:
		quad.size *= 0.4
	quad.material = _flame_material() if flame else _spark_material()
	emitter.draw_pass_1 = quad
	return emitter
