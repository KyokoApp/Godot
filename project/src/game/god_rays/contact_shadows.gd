extends MeshInstance3D
## Contact shadow layar-penuh: sinar ditembakkan dari setiap piksel ke arah
## matahari dan dibandingkan dengan buffer kedalaman (lihat
## contact_shadows.gdshader). Menambah bayangan kontak di kaki objek yang selalu
## hilang dari shadow map — kesan "ray tracing" yang tetap jalan di renderer
## Mobile, karena SSAO/SSR/volumetric fog hanya ada di Forward+.
const SHADER = preload("res://src/game/god_rays/contact_shadows.gdshader")
const Dusk = preload("res://src/game/environment/dusk_environment.gd")

var camera: Camera3D
var enabled := true

var _material: ShaderMaterial


func _ready() -> void:
	name = "ContactShadows"
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	mesh = quad
	extra_cull_margin = 16384
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	# render_priority milik MATERIAL (BaseMaterial3D), bukan node: sinar matahari
	# memakai -100, jadi -101 menggambar contact shadow LEBIH DULU — gelapkan
	# dulu, baru sinar matahari menambah cahaya. Urutan yang lebih masuk akal.
	_material.render_priority = -101
	_material.set_shader_parameter("sun_direction", Dusk.SUN_DIRECTION)
	material_override = _material
	visible = false


func _process(_delta: float) -> void:
	if not enabled or not is_instance_valid(camera) or not camera.current:
		visible = false
		return
	visible = true
