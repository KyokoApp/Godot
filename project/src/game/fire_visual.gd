extends RefCounted
## Mesh/material dibagi oleh pet, peluru dan ledakan. Tanpa lampu/shadow ekstra.

const FIRE = preload("res://src/game/spirit_fire.gdshader")
const OUTLINE = preload("res://src/game/character_outline.gdshader")

static var _sphere: SphereMesh
static var _material: ShaderMaterial


static func make_orb(radius: float) -> MeshInstance3D:
	if _sphere == null:
		_sphere = SphereMesh.new()
		_sphere.radius = 1.0
		_sphere.height = 2.0
		_sphere.radial_segments = 20
		_sphere.rings = 10
		_material = ShaderMaterial.new()
		_material.shader = FIRE
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE
		outline.set_shader_parameter("outline_width", 0.025)
		outline.set_shader_parameter("outline_color", Color("25214a"))
		_material.next_pass = outline
	var mesh := MeshInstance3D.new()
	mesh.mesh = _sphere
	mesh.material_override = _material
	mesh.scale = Vector3.ONE * radius
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.extra_cull_margin = radius * 0.6
	return mesh
