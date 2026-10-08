shader_type spatial;
// Pita jejak kecepatan (dash).
//
// Ini BUKAN afterimage: tidak ada salinan pose/kerangka/tekstur karakter.
// Hanya SATU pita geometri aditif yang mengikuti jejak posisi karakter —
// lebar dan terang di dekat karakter, menyempit dan memudar ke belakang.
// Hasilnya terbaca sebagai garis gerak / motion blur, bukan "bayangan badan".
//
// Murah untuk HP: 22 ruas segitiga, tanpa tekstur, tanpa bayangan, satu
// ImmediateMesh yang ditulis ulang tiap frame.

render_mode blend_add, cull_disabled, depth_draw_never, unshaded;

// Warna pita: ungu mannequin, intinya hampir putih supaya melewati ambang
// glow (1.15) dan benar-benar mekar, bukan cuma "garis ungu polos".
uniform vec4 tint : source_color = vec4(0.79, 0.65, 1.00, 1.00);
uniform vec4 core : source_color = vec4(1.60, 1.45, 2.00, 1.00);
// Kekuatan keseluruhan pita (0 = tidak kelihatan), diatur dari speed_trail.gd.
uniform float strength : hint_range(0.0, 1.0) = 1.0;
// Seberapa besar bagian tengah pita yang ikut mekar (0 = tipis sekali).
uniform float width : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	// UV.x = 0 di kepala pita (dekat karakter), 1 di ekor (paling lama).
	// UV.y = 0..1 melintasi lebar pita, 0.5 = garis tengah.
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	float soft = pow(clamp(across / width, 0.0, 1.0), 1.7);
	float tail = 1.0 - clamp(UV.x, 0.0, 1.0);
	// Inti pita hampir putih dan terang; tepinya cuma warna ungu tipis.
	vec3 color = mix(tint.rgb, core.rgb, soft * soft);
	ALBEDO = color;
	ALPHA = soft * tail * tail * strength * 0.5;
}
