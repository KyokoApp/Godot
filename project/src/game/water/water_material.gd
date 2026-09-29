extends RefCounted

const SHADER = preload("res://src/game/water/water.gdshader")
const HEIGHT = preload("res://assets/water/wave_height.png")
const NORMAL = preload("res://assets/water/wave_normal.png")
const Night = preload("res://src/game/environment/night_environment.gd")


static func create(ocean := false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("wave_a", HEIGHT)
	material.set_shader_parameter("wave_b", HEIGHT)
	material.set_shader_parameter("surface_normals_a", NORMAL)
	material.set_shader_parameter("surface_normals_b", NORMAL)
	material.set_shader_parameter("moon_direction", Night.MOON_DIRECTION)
	material.set_shader_parameter("ssr_enabled", false)
	material.set_shader_parameter("ocean", ocean)
	return material
