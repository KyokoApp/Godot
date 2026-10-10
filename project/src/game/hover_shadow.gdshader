shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;


void fragment() {
	vec2 centered_uv = UV * 2.0 - 1.0;
	float radius = length(centered_uv);
	float opacity = 0.28 * (1.0 - smoothstep(0.3, 1.0, radius));
	ALBEDO = vec3(0.045, 0.085, 0.19);
	ALPHA = opacity;
}
