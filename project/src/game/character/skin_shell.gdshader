shader_type spatial;
// Kulit beranimasi untuk mannequin.
//
// Dipakai DUA kali dengan bahan yang sama supaya tidak ada bagian mannequin yang
// pernah terlihat telanjang:
//   1. sebagai material mesh mannequin sendiri (lapisan dalam), dan
//   2. sebagai material "kulit" salinan mesh yang digelembungkan `grow` meter
//      mengikuti normal (lapisan luar, lihat character/skin_shell.gd).
// Karena keduanya sama, bagian yang menonjol di lipatan tajam (siku/lutut) tidak
// pernah menampakkan warna mannequin polos.
//
// Gerakannya: HANYA denyut tipis di pinggir siluet (rim) yang menguat saat
// pemain bergerak/berlari (`pulse`) atau menyerang/mantra (`charge`). Semua
// murah untuk GPU mobile: tanpa loop, tanpa tekstur, tanpa layar penuh.
//
// Palet: HITAM POLOS (permintaan pengguna 2026-10-02). Garis energi yang
// mengalir dan percikan kecil SUDAH DIHAPUS — tubuh kembali jadi hitam rata
// dengan gradasi sangat gelap kaki→kepala, dan siluetnya diberi garis tepi
// PUTIH tipis oleh `character_outline.gdshader`. Hasilnya: badan hitam polos,
// tepi putih.

render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// Hitam polos: dasar nyaris hitam, arah kepala sedikit lebih terang (tetap gelap)
// supaya gradasi tinggi badan tetap membentuk siluet.
uniform vec4 skin_dark : source_color = vec4(0.010, 0.011, 0.014, 1.0);
uniform vec4 skin_light : source_color = vec4(0.050, 0.053, 0.065, 1.0);
// Garis energi: DIHAPUS. Uniform-nya sengaja masih dideklarasikan supaya
// `set_light_cloth()` di mannequin.gd (mode grafis Ringan) tidak menyetel
// parameter yang tidak ada di shader — nilainya tidak lagi dipakai di sini.
uniform vec4 vein_color : source_color = vec4(0.32, 0.34, 0.40, 1.0);
uniform float vein_scale = 16.5;
uniform float vein_width = 0.105;
uniform vec4 rim_color : source_color = vec4(0.62, 0.65, 0.74, 1.0);
uniform float body_scale = 2.2;
uniform float rim_power = 2.4;
uniform float rim_strength = 0.55;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float charge : hint_range(0.0, 1.0) = 0.0;
// Bloom dash (permintaan ronde 18: "efek blur/glow di karakter"). Nilai > 0
// menambah pancaran terang di pinggir siluet yang sengaja dibuat MELEBIHI
// ambang glow (1.15), jadi karakter benar-benar mekar saat dash — bukan cuma
// garis tepi yang naik sedikit. Badan tetap hitam: yang menyala hanya rim.
uniform vec4 bloom_color : source_color = vec4(0.80, 0.62, 1.20, 1.0);
uniform float bloom : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.42;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float grow = 0.0;

float shell_hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	VERTEX += NORMAL * grow;
}

void fragment() {
	// Tinggi badan memakai koordinat model: gradasi terang di badan, gelap di
	// kaki, jadi siluetnya terbaca walau jarak kamera jauh.
	float height_mix = clamp(0.5 + 0.5 * normalize(VERTEX + vec3(0.0, 0.9, 0.0)).y, 0.0, 1.0);
	vec3 albedo = mix(skin_dark.rgb, skin_light.rgb, height_mix);
	// Bercak halus: badan tidak boleh terlihat seperti plastik rata, tapi juga
	// tidak boleh bergaris seperti perban. Ini SATU-SATUNYA variasi permukaan
	// yang tersisa — garis energi dan percikannya sudah dihapus.
	vec2 flow_uv = vec2(VERTEX.x + VERTEX.z * 0.6, VERTEX.y * body_scale);
	albedo *= 0.93 + 0.15 * shell_hash(floor(flow_uv * 9.0));

	// Denyut: rim menguat saat pemain bergerak (pulse) dan saat menyerang/mantra
	// (charge). Tidak ada gelombang yang berjalan di sepanjang badan — tubuh
	// harus tetap POLOS; hanya kekuatan rim yang berubah.
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0),
		rim_power);
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	// Satu-satunya cahaya yang tersisa: rim abu tipis di pinggir siluet. Di badan
	// hitam polos ini yang menjaga bentuk bahu/kepala tetap terbaca, tanpa
	// membuat tubuhnya terlihat abu-abu.
	EMISSION = rim_color.rgb * rim * rim_strength * (0.35 + pulse * 0.65 + charge * 0.5)
		+ bloom_color.rgb * bloom * (rim * 1.45 + 0.22);
	SPECULAR = 0.35;
}
