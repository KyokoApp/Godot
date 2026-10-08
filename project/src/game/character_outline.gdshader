shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

// Inverted hull tipis untuk mannequin berskin, bukan post-process seluruh dunia.
// Mannequin kini berwarna HITAM GELAP, jadi garis tepinya harus PUTIH dan tipis:
// tanpa itu siluetnya larut di tempat gelap (dan di langit terang sekalipun
// bentuk badannya tidak terbaca). Lebar bawaan 5 mm — cukup terlihat, tidak
// membuat siluetnya membengkak.
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float outline_width : hint_range(0.0, 0.02) = 0.005;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
