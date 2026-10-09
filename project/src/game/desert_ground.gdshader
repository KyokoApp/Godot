shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D sand_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 wind_axis = vec2(0.82, 0.57);
uniform float texture_scale = 0.032;

varying vec3 world_position;
varying vec3 world_normal;


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}


void fragment() {
	vec3 grain = texture(sand_albedo, world_position.xz * texture_scale).rgb;
	float ripple_phase = dot(world_position.xz, normalize(wind_axis)) * 2.15
		+ (grain.r - grain.g) * 4.0;
	float ripples = smoothstep(0.35, 0.96, sin(ripple_phase)) * 0.055;
	float sunward = clamp(world_normal.y * 0.55 + 0.45, 0.0, 1.0);
	vec3 sand_tint = mix(vec3(0.82, 0.66, 0.45), vec3(1.02, 0.86, 0.63), sunward);
	ALBEDO = grain * sand_tint * (0.96 + ripples);
	ROUGHNESS = 0.97;
	SPECULAR = 0.10;
}
