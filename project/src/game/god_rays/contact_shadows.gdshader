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
// Catatan Godot: 'return' dan 'break' TIDAK boleh dipakai di fragment(), dan
// matriks bawaan (VIEW_MATRIX, PROJECTION_MATRIX) hanya dikenali di vertex()
// atau fragment() — bukan di fungsi buatan sendiri.
render_mode unshaded, blend_mul, cull_disabled, depth_draw_never, depth_test_disabled,
	shadows_disabled, fog_disabled;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
// Arah matahari SUDAH dalam ruang kamera (dihitung contact_shadows.gd): Godot
// tidak mengenal VIEW_MATRIX di fungsi buatan sendiri, dan di fragment() ia
// mahal dihitung ulang per piksel.
uniform vec3 sun_direction_view = vec3(-0.94, 0.09, -0.32);
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
			// Sinar ditembakkan ke arah matahari. Semua matriks bawaan Godot
			// dipakai DI SINI (fragment), bukan di fungsi terpisah: Godot tidak
			// mengenali VIEW_MATRIX di fungsi buatan sendiri. Tanpa 'return' dan
			// tanpa 'break' — keduanya dilarang di fragment().
			vec3 step = sun_direction_view * (ray_length / float(SAMPLE_COUNT));
			vec3 ray = origin;
			bool blocked = false;
			for (int i = 0; i < SAMPLE_COUNT && !blocked; i++) {
				ray += step;
				vec4 clip = PROJECTION_MATRIX * vec4(ray, 1.0);
				vec2 uv = (clip.xy / clip.w) * 0.5 + 0.5;
				// Sinar yang keluar layar dilewati, bukan menghentikan loop.
				if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
					float ray_depth = clip.z / clip.w;
					float scene = texture(depth_tex, uv).r;
					// Reverse-Z: benda lebih DEKAT ke kamera = nilai lebih BESAR.
					blocked = scene > ray_depth + bias;
				}
			}
			shadow = blocked ? 1.0 : 0.0;
		}
	}
	// Memudar di 10% tepi layar: ray yang keluar layar jangan membuat tepian.
	vec2 fade = max(vec2(0.0), 10.0 * abs(SCREEN_UV - 0.5) - 4.0);
	float edge = clamp(dot(fade, fade), 0.0, 1.0);
	ALBEDO = vec3(mix(1.0, strength, shadow * (1.0 - edge)));
	ALPHA = 1.0;
}
