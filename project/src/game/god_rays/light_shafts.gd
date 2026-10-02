class_name LightShafts
extends ColorRect

## Sinar matahari bergaya god rays pend00 (shader canvas_item, lisensi CC0).
## Dipasang sebagai ColorRect layar penuh di bawah HUD: shader membaca layar yang
## sudah dirender lalu mencampur sinar prosedural. Setiap frame posisi matahari di
## layar diubah menjadi arah dan pusat pantulan sinar, jadi sinar selalu muncul dari
## arah matahari dan hilang saat matahari ada di belakang kamera.

const Dusk = preload("res://src/game/environment/dusk_environment.gd")
const SUN_DIRECTION := Dusk.SUN_DIRECTION
const SUN_DISTANCE := 900.0
const RAY_COLOR := Color(1.0, 0.86, 0.68)
const _SHADER := preload("res://src/game/god_rays/light_shafts.gdshader")

var camera: Camera3D
var enabled := true
var strength := 0.45


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = _SHADER
	material = shader_material


func _process(_delta: float) -> void:
	visible = _update()


func _update() -> bool:
	if not enabled or camera == null or material == null:
		return false
	var target := camera.global_position + SUN_DIRECTION * SUN_DISTANCE
	if camera.to_local(target).z > -0.05:
		# Matahari di belakang kamera: sinar tak terlihat.
		return false
	var viewport_size := get_viewport_rect().size
	var screen: Vector2 = camera.unproject_position(target)
	var uv := Vector2(screen.x / viewport_size.x, screen.y / viewport_size.y)
	# Memudar saat matahari keluar layar, biar sinar tidak terpotong kasar.
	var outside_x: float = maxf(0.0, maxf(-uv.x, uv.x - 1.0))
	var outside_y: float = maxf(0.0, maxf(-uv.y, uv.y - 1.0))
	var fade: float = clampf(1.0 - (outside_x + outside_y) * 1.2, 0.0, 1.0)
	var alpha: float = strength * fade
	if alpha <= 0.01:
		return false
	# Sinar menyebar dari matahari menuju pusat layar.
	var away := Vector2(0.5 - uv.x, 0.5 - uv.y)
	material.set_shader_parameter("ray_origin", uv)
	material.set_shader_parameter("ray_angle", atan2(-away.x, away.y))
	material.set_shader_parameter("color", Color(RAY_COLOR, alpha))
	return true
