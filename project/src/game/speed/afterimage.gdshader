shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;
uniform float opacity = 0.0;
void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 0.7);
	ALBEDO = vec3(0.9, 0.95, 1.0);
	ALPHA = opacity * mix(0.38, 1.0, rim);
}
