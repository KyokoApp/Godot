shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float fog_amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Large slow folds instead of sharp stripes or a flat white dome.
	float broad = sin(UV.x * 21.0 + TIME * 0.17 + sin(UV.y * 13.0) * 1.6);
	float wisps = sin(UV.x * 49.0 - UV.y * 17.0 - TIME * 0.12);
	float shade = 0.77 + 0.045 * broad + 0.022 * wisps;
	ALBEDO = vec3(shade, shade + 0.013, shade + 0.025);
	// Two nested shells combine to >99.9% occlusion at full strength.
	ALPHA = fog_amount * 0.985;
}
