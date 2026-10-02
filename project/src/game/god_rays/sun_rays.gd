extends MeshInstance3D
## Sinar matahari (radial scattering) dari arah matahari rendah di ilustrasi layar
## muat; versi Mobile, tanpa render scene kedua.
const SHADER = preload("res://src/game/god_rays/sun_rays.gdshader")
const Dusk = preload("res://src/game/environment/dusk_environment.gd")
var camera: Camera3D
var enabled := true
var strength := 0.0
var _material: ShaderMaterial


func _ready() -> void:
	name = "SunRays"
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	mesh = quad
	extra_cull_margin = 16384
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.render_priority = -100 # Before transparent water, aurora and particles.
	material_override = _material
	visible = false


func _process(_delta: float) -> void:
	strength = 0.0
	if not enabled or not is_instance_valid(camera) or not camera.current:
		visible = false
		return
	var source := camera.global_position + Dusk.SUN_DIRECTION * 1000.0
	if camera.is_position_behind(source):
		visible = false
		return
	var size := camera.get_viewport().get_visible_rect().size
	var uv := camera.unproject_position(source) / size
	var edge := minf(minf(uv.x, 1.0 - uv.x), minf(uv.y, 1.0 - uv.y))
	strength = smoothstep(0.0, 0.12, edge) * 0.16
	visible = strength > 0.0001
	_material.set_shader_parameter("source_uv", uv)
	_material.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_material.set_shader_parameter("strength", strength)
