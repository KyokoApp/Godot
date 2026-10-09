shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D sand_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 wind_axis = vec2(0.82, 0.57);
uniform vec3 sun_direction = vec3(-0.608, 0.52, -0.599);
uniform float texture_scale = 0.065;

varying vec3 world_position;
varying vec3 world_normal;


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}


void fragment() {
	vec3 grain = texture(sand_albedo, world_position.xz * texture_scale).rgb;
	float ripple_phase = dot(world_position.xz, normalize(wind_axis)) * 2.7
		+ (grain.r - grain.g) * 4.0;
	float ripples = smoothstep(0.28, 0.94, sin(ripple_phase)) * 0.075;
	float sunward = clamp(dot(world_normal, normalize(sun_direction)) * 1.15 + 0.08,
		0.0, 1.0);
	vec3 shadow_sand = vec3(0.55, 0.37, 0.24);
	vec3 lit_sand = vec3(0.98, 0.77, 0.53);
	vec3 sand_tint = mix(shadow_sand, lit_sand, sunward);
	ALBEDO = grain * sand_tint * (0.95 + ripples);
	ROUGHNESS = 0.97;
	SPECULAR = 0.10;
}
