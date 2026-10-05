shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform vec4 tint : source_color = vec4(0.82, 0.54, 1.0, 1.0);
uniform float opacity = 1.0;

void fragment() {
	float across = abs(UV.y - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.16, 0.92, across);
	float tips = 1.0 - smoothstep(0.25, 0.50, abs(UV.x - 0.5));
	float edge = 0.66 + 0.34 * sin(UV.x * 57.0);
	ALBEDO = tint.rgb;
	EMISSION = tint.rgb * 3.2;
	ALPHA = tint.a * opacity * core * tips * edge;
}
