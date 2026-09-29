shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color;
uniform float opacity = 0.0;
uniform float phase = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float clouds = sin(p.x * 9.0 + phase + sin(p.y * 7.0)) * 0.10;
	clouds += sin(p.y * 13.0 - phase * 0.5 + p.x * 4.0) * 0.06;
	float soft = 1.0 - smoothstep(0.16, 1.0, length(p) + clouds);
	ALBEDO = mix(tint.rgb, vec3(0.6, 0.64, 0.68), 0.55);
	ALPHA = soft * soft * opacity;
}
