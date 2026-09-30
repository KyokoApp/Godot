shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

// Inverted hull tipis untuk mannequin berskin, bukan post-process seluruh dunia.
uniform vec4 outline_color : source_color = vec4(0.13, 0.12, 0.18, 1.0);
uniform float outline_width : hint_range(0.0, 0.02) = 0.006;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
