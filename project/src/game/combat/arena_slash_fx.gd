extends Node3D
## A short, camera-facing double ribbon with a hot core and a soft additive edge.

const DURATION := 0.34
const SEGMENTS := 28

var age := 0.0
var effect_tint := Color(0.38, 0.82, 1.0)
var power := 1.0
var _materials: Array[StandardMaterial3D] = []
var _base_colors: Array[Color] = []
var _base_energy: Array[float] = []
var _flash: OmniLight3D


func configure(origin: Vector3, facing: Vector3, tint: Color, strength: float) -> void:
	global_position = origin
	effect_tint = tint
	power = clampf(strength, 0.6, 1.6)
	var direction := facing
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	look_at(global_position + direction.normalized(), Vector3.UP)
	_add_ribbon(2.1 * power, 0.46 * power, 0.19 * power, 0.02,
		Color(tint.r, tint.g, tint.b, 0.46), 1.5)
	_add_ribbon(1.72 * power, 0.35 * power, 0.055 * power, -0.035,
		Color(1.0, 0.97, 0.88, 0.92), 3.2)
	_flash = OmniLight3D.new()
	_flash.name = "SlashFlash"
	_flash.light_color = tint
	_flash.omni_range = 2.8 * power
	_flash.light_energy = 1.45
	_flash.shadow_enabled = false
	add_child(_flash)


func _add_ribbon(span: float, rise: float, width: float, depth: float,
		color: Color, energy: float) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = effect_tint
	material.emission_energy_multiplier = energy
	material.disable_receive_shadows = true
	material.disable_ambient_light = true
	var ribbon := MeshInstance3D.new()
	ribbon.mesh = _make_ribbon(span, rise, width, depth)
	ribbon.material_override = material
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ribbon.extra_cull_margin = 2.5
	add_child(ribbon)
	_materials.append(material)
	_base_colors.append(color)
	_base_energy.append(energy)


func _make_ribbon(span: float, rise: float, width: float, depth: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in range(SEGMENTS + 1):
		var along := float(index) / SEGMENTS
		var curve := maxf(sin(along * PI), 0.0)
		var x := lerpf(-span * 0.5, span * 0.5, along)
		var center := Vector3(x, curve * rise - 0.06 * power, depth)
		var taper := width * (0.12 + 0.88 * pow(curve, 0.55))
		var alpha := 0.18 + 0.82 * curve
		mesh.surface_set_normal(Vector3.BACK)
		mesh.surface_set_color(Color(1, 1, 1, alpha))
		mesh.surface_add_vertex(center + Vector3(0, taper, 0))
		mesh.surface_set_color(Color(1, 1, 1, alpha))
		mesh.surface_add_vertex(center - Vector3(0, taper, 0))
	mesh.surface_end()
	return mesh


func _process(delta: float) -> void:
	age += delta
	var progress := clampf(age / DURATION, 0.0, 1.0)
	var fade := pow(1.0 - progress, 1.55)
	scale = Vector3.ONE * lerpf(0.84, 1.13, progress)
	rotation.z = lerpf(-0.20, 0.13, progress)
	rotation.y = sin(progress * PI) * 0.10
	for index in range(_materials.size()):
		var color: Color = _base_colors[index]
		color.a *= fade
		_materials[index].albedo_color = color
		_materials[index].emission_energy_multiplier = _base_energy[index] * fade
	if _flash != null:
		_flash.light_energy = 1.45 * fade
		_flash.visible = progress < 0.6
	if progress >= 1.0:
		queue_free()
