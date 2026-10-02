shader_type spatial;
// Contact shadow layar-penuh: dari SETIAP piksel satu sinar ditembakkan ke arah
// matahari lalu dibandingkan dengan buffer kedalaman. Ini "ray tracing" murah
// yang jalan di renderer Mobile — SSAO, SSR, SSIL, dan volumetric fog di Godot
// hanya tersedia di Forward+, jadi proyek ini (renderer Mobile) harus menirunya.
//
// Bayangan peta (shadow map) sudah menangani bayangan panjang. Yang selalu hilang
// dari peta adalah bagian KONTAK: tepat di kaki objek, di tempat peta resolusi
// terbatasnya peter-panning. Lapisan ini menambah bagian itu saja.
//
// Adaptasi teknik Screen Space Shadows dari forum Godot (lihat LICENSES.txt):
//   ndc  = vec3(SCREEN_UV * 2.0 - 1.0, depth)   // Godot 4: NDC y sudah
//                                               // mengikuti layar, TANPA flip
//   view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0); posisi = view.xyz / view.w
//   depth buffer reverse-Z: DEKAT = 1.0, JAUH = 0.0
//
// Catatan Godot: 'return' TIDAK boleh dipakai di fragment(), jadi alurnya
// dibagi ke fungsi kecil _march() yang memang boleh return.
render_mode unshaded, blend_mul, cull_disabled, depth_draw_never, depth_test_disabled,
	shadows_disabled, fog_disabled;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 sun_direction = vec3(-0.94, 0.09, -0.32);
// Sinar 21 m dengan langkah 1,5 m: cukup jauh untuk kontak objek setinggi
// karakter, cukup pendek supaya 14 sampel tetap murah di HP.
uniform float ray_length = 21.0;
uniform float max_distance = 55.0;
// Pengerasan sedikit di bawah 1,0 supaya efeknya menanam, bukan menghitamkan.
uniform float strength = 0.74;
uniform float bias = 0.0004;
const int SAMPLE_COUNT = 14;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// Menembakkan satu sinar dari posisi piksel ke arah matahari. Mengembalikan 1.0
// kalau sinar kena geometri (bayangan), 0.0 kalau langit terang.
float _march(vec3 origin) {
	vec3 sun_view = (VIEW_MATRIX * vec4(sun_direction, 0.0)).xyz;
	sun_view = normalize(sun_view);
	vec3 step = sun_view * (ray_length / float(SAMPLE_COUNT));
	vec3 ray = origin;
	for (int i = 0; i < SAMPLE_COUNT; i++) {
		ray += step;
		vec4 clip = PROJECTION_MATRIX * vec4(ray, 1.0);
		vec2 uv = (clip.xy / clip.w) * 0.5 + 0.5;
		// Sinar yang keluar layar tidak boleh meninggalkan garis di tepi.
		if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
			return 0.0;
		}
		float ray_depth = clip.z / clip.w;
		float scene = texture(depth_tex, uv).r;
		// Reverse-Z: benda yang lebih DEKAT ke kamera punya nilai lebih BESAR.
		if (scene > ray_depth + bias) {
			return 1.0;
		}
	}
	return 0.0;
}

void fragment() {
	float raw = texture(depth_tex, SCREEN_UV).r;
	float shadow = 0.0;
	// Langit (reverse-Z: tak hingga = 0) tidak butuh contact shadow.
	if (raw >= 0.00001) {
		vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw);
		vec4 corner = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		vec3 origin = corner.xyz / corner.w;
		// Jauh dari kamera kontaknya tidak terbaca lagi: hemat setengah layar.
		if (length(origin) <= max_distance) {
			shadow = _march(origin);
		}
	}
	// Memudar di 10% tepi layar: ray yang keluar layar jangan membuat tepian.
	vec2 fade = max(vec2(0.0), 10.0 * abs(SCREEN_UV - 0.5) - 4.0);
	float edge = clamp(dot(fade, fade), 0.0, 1.0);
	ALBEDO = vec3(mix(1.0, strength, shadow * (1.0 - edge)));
	ALPHA = 1.0;
}
