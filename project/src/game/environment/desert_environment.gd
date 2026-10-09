extends RefCounted
## Clear, dusty late-afternoon light: warm horizon haze, cool high sky, no night sky or bloom.

const SKY_SHADER = preload("res://src/game/environment/desert_sky.gdshader")
const SUN_DIRECTION := Vector3(-0.608, 0.52, -0.599)


static func make_environment() -> Environment:
	var sky_material := ShaderMaterial.new()
	sky_material.shader = SKY_SHADER
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_QUALITY

	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("c6ab82")
	environment.ambient_light_energy = 0.42
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = Color("d2b58b")
	environment.fog_light_energy = 0.78
	environment.fog_depth_begin = 210.0
	environment.fog_depth_end = 1080.0
	environment.fog_depth_curve = 1.12
	environment.fog_sky_affect = 0.14
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.94
	environment.adjustment_contrast = 1.03
	# Keep the fire's light local; a full-screen bloom would wash out the sand.
	environment.glow_enabled = false
	return environment


static func make_sunlight() -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = "AfternoonSun"
	light.light_color = Color("ffe0ad")
	light.light_energy = 1.08
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 300.0
	return light
