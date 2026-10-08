shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.58, 0.35, 1.0, 1.0);
uniform float strength = 0.55;
uniform float hit_flash = 0.0;

void fragment() {
	float facing = clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.4);
	vec2 cell = abs(fract(UV * vec2(14.0, 9.0)) - 0.5);
	float seam = 1.0 - smoothstep(0.018, 0.065, min(cell.x, cell.y));
	float pulse = 0.76 + 0.24 * sin(TIME * 2.6 + UV.y * 18.0);
	float energy = strength * pulse * (rim * 0.72 + seam * 0.18 + hit_flash * rim * 0.9);
	ALBEDO = tint.rgb * (0.55 + energy);
	EMISSION = tint.rgb * energy * 2.2;
	ALPHA = clamp((rim * 0.19 + seam * 0.07) * strength * pulse + hit_flash * rim * 0.16,
		0.0, 0.56);
}
