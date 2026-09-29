shader_type canvas_item;
render_mode unshaded;
uniform vec4 tint : source_color = vec4(0.25, 0.6, 1.0, 1.0);
uniform float strength = 0.0;
void fragment() {
	vec2 centered = (UV - 0.5) * 2.0;
	float edge = smoothstep(0.25, 1.2, length(centered));
	COLOR = vec4(tint.rgb, strength * (0.025 + edge * 0.13));
}
