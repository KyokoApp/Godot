shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
void fragment() {
	float wave = sin(UV.x * 85.0 + sin(UV.x * 39.0 + TIME * 0.35) * 2.0 - TIME * 0.5);
	float folds = 0.5 + 0.5 * wave;
	float vertical = smoothstep(0.0, 0.12, UV.y) * pow(1.0 - UV.y, 1.8);
	ALBEDO = mix(vec3(0.43, 0.46, 0.49), vec3(0.85, 0.88, 0.9), folds);
	EMISSION = ALBEDO * 0.22;
	ALPHA = vertical * (0.18 + folds * 0.48);
}
