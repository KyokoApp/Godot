shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform float flight_blend = 0.0;


void fragment() {
	vec2 centered_uv = UV * 2.0 - 1.0;
	float radius = length(centered_uv);
	float feather = 1.0 - smoothstep(0.18, 1.0, radius);
	float center_glow = 1.0 - smoothstep(0.08, 0.82, radius);
	vec3 resting_shadow = vec3(0.045, 0.06, 0.12);
	vec3 flight_pool = vec3(0.025, 0.14, 0.48);
	ALBEDO = mix(resting_shadow, flight_pool, flight_blend);
	EMISSION = vec3(0.018, 0.10, 0.38) * center_glow * flight_blend;
	ALPHA = feather * mix(0.24, 0.38, flight_blend);
}
