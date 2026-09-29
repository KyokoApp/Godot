extends RefCounted
## Shared preset for gameplay and real renderer regression tests.

const SKY_SHADER = preload("res://src/game/environment/night_sky.gdshader")
const MOON_DIRECTION := Vector3(-0.31, 0.24, -0.92).normalized()


static func make_environment() -> Environment:
	var material := ShaderMaterial.new()
	material.shader = SKY_SHADER
	material.set_shader_parameter("moon_direction", MOON_DIRECTION)
	var sky := Sky.new()
	sky.sky_material = material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	# Deliberately readable night, independent of the near-black sky cubemap.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.48, 0.57, 0.78)
	environment.ambient_light_energy = 0.38
	environment.reflected_light_source = Environment.REFLECTED_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	return environment


static func make_moonlight() -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = "Moonlight"
	light.light_color = Color(0.68, 0.78, 1.0)
	light.light_energy = 0.48
	light.shadow_enabled = true
	return light
