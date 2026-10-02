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
// Gerakannya: pola energi mengalir naik-turun badan, denyut yang menguat saat
// pemain bergerak/berlari (`pulse`), dan garis tepi yang menyala. Semua murah
// untuk GPU mobile: tanpa loop, tanpa tekstur, tanpa layar penuh.
//
// Palet: HITAM GELAP. Tubuh mannequin nyaris hitam (hanya gradasi sangat gelap
// dari kaki ke kepala supaya bentuknya tetap terbaca), garis energi dan rim
// berupa abu gelap yang tipis, dan siluetnya diberi garis tepi PUTIH tipis oleh
// `character_outline.gdshader`. Hasilnya: badan hitam, tepi putih.

render_mode cull_back, depth_draw_opaque, diffuse_burley, specular_schlick_ggx;

// Hitam gelap: dasar nyaris hitam, arah kepala sedikit lebih terang (tetap gelap)
// supaya gradasi tinggi badan tetap membentuk siluet.
uniform vec4 skin_dark : source_color = vec4(0.010, 0.011, 0.014, 1.0);
uniform vec4 skin_light : source_color = vec4(0.050, 0.053, 0.065, 1.0);
// Garis energi & kilau: abu gelap, bukan warna — tubuh harus tetap terbaca hitam.
uniform vec4 vein_color : source_color = vec4(0.32, 0.34, 0.40, 1.0);
uniform vec4 rim_color : source_color = vec4(0.62, 0.65, 0.74, 1.0);
uniform float vein_scale = 16.5;
uniform float vein_speed = 0.20;
uniform float vein_width = 0.105;
uniform float body_scale = 2.2;
uniform float rim_power = 2.4;
uniform float rim_strength = 0.55;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform float charge : hint_range(0.0, 1.0) = 0.0;
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
	vec3 base = mix(skin_dark.rgb, skin_light.rgb, height_mix);
	// Bercak halus: badan tidak boleh terlihat seperti plastik rata, tapi juga
	// tidak boleh bergaris seperti perban.
	vec2 flow_uv = vec2(VERTEX.x + VERTEX.z * 0.6, VERTEX.y * body_scale);
	base *= 0.93 + 0.15 * shell_hash(floor(flow_uv * 9.0));
	float band = sin((flow_uv.x + flow_uv.y) * vein_scale - TIME * vein_speed * 6.283185);
	float band_b = sin((flow_uv.x * 0.6 - flow_uv.y * 1.3) * vein_scale * 0.7
		+ TIME * vein_speed * 4.1);
	// Garis energi TIPIS di puncak gelombang, bukan pita lebar: ambangnya dekat
	// 1,0 sehingga hanya bagian sempit di sekitar puncak |sin| yang menyala.
	// `vein_width` mengatur ketebalannya (makin besar makin lebar).
	float threshold = clamp(1.0 - vein_width * 0.35, 0.0, 0.999);
	float vein = smoothstep(threshold, 1.0, abs(band))
		+ smoothstep(threshold, 1.0, abs(band_b)) * 0.55;
	vein = clamp(vein, 0.0, 1.0);

	// Denyut: menguat saat pemain bergerak (pulse) dan saat menyerang/mantra
	// (charge). Fase berbeda-beda di sepanjang badan supaya terasa mengalir.
	float wave = 0.5 + 0.5 * sin(VERTEX.y * 6.0 - TIME * (2.0 + 4.0 * pulse));
	float beat = mix(0.35, 1.0, wave) * (0.35 + 0.65 * pulse + 0.5 * charge);

	vec3 albedo = mix(base, vein_color.rgb, vein * 0.70);
	albedo += vein_color.rgb * vein * beat * 0.25;

	// Percikan kecil tetap di permukaan supaya kulit tidak terlihat datar.
	float sparkle = shell_hash(floor(flow_uv * 26.0)) * smoothstep(0.985, 1.0,
		shell_hash(floor(flow_uv * 26.0) + vec2(3.7, 1.3)));
	albedo += vein_color.rgb * sparkle * (0.2 + 0.8 * pulse);

	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0),
		rim_power);
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	// Garis tepi yang menyala: siluet badan tetap terbaca walau di tempat gelap.
	// Di badan hitam, rim memakai abu terang (`rim_color`) — cukup untuk membaca
	// bentuk bahu/kepala tanpa membuat tubuhnya terlihat abu-abu.
	EMISSION = (vein_color.rgb * vein * 0.30
		+ rim_color.rgb * rim * rim_strength * 0.35) * (0.25 + pulse * 0.5);
	SPECULAR = 0.35;
}
