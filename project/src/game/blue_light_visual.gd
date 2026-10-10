extends Node3D
## Smooth, gently rippling blue light orb; flight glow blends in with the player form.

const LIGHT_SHADER = preload("res://src/game/blue_light_blob.gdshader")
const ORB_RADIUS := 0.24

var flight_blend := 0.0
var motion_strength := 0.0

var _orb: MeshInstance3D
var _light: OmniLight3D
var _material: ShaderMaterial
var _time := 0.0


func _ready() -> void:
	name = "BlueLightVisual"
	_build_orb()
	_build_aura()


func _process(delta: float) -> void:
	_time += delta
	var pulse := 0.5 + 0.5 * sin(_time * 2.1)
	var scale_pulse := sin(_time * 1.7 + 0.4) * 0.018
	var target_scale := 0.96 + flight_blend * 0.08 + scale_pulse + motion_strength * 0.012
	_orb.scale = _orb.scale.lerp(Vector3.ONE * target_scale, 1.0 - exp(-5.0 * delta))
	_material.set_shader_parameter("flight_blend", flight_blend)
	_material.set_shader_parameter("motion_strength", motion_strength)
	_light.light_energy = 0.16 + flight_blend * (0.65 + pulse * 0.20)
	_light.omni_range = 0.82 + flight_blend * 0.88


func _build_orb() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = ORB_RADIUS
	sphere.height = ORB_RADIUS * 2.0
	sphere.radial_segments = 40
	sphere.rings = 24
	_orb = MeshInstance3D.new()
	_orb.name = "BlueWaveOrb"
	_orb.mesh = sphere
	_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orb.extra_cull_margin = 0.1
	_material = ShaderMaterial.new()
	_material.shader = LIGHT_SHADER
	_material.set_shader_parameter("flight_blend", 0.0)
	_material.set_shader_parameter("motion_strength", 0.0)
	_orb.material_override = _material
	add_child(_orb)


func _build_aura() -> void:
	_light = OmniLight3D.new()
	_light.name = "BlueAura"
	_light.light_color = Color("286dff")
	_light.light_energy = 0.16
	_light.omni_range = 0.82
	_light.omni_attenuation = 1.45
	_light.light_specular = 0.85
	_light.shadow_enabled = false
	add_child(_light)
