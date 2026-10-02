shader_type spatial;
// Sinar matahari (god rays): adaptasi metode "Screen Space God Rays" dari
// godotshaders.com (kredit + lisensi di project/licenses/LICENSES.txt) — kabur
// RADIAL dari posisi matahari di layar, dipotong geometri, sehingga keluar
// shaft panjang, bukan hanya bercak di dekat matahari.
//
// Bedanya dengan shader aslinya, dan ini disengaja:
//   - TIDAK memakai SubViewport. Shader aslinya me-render scene KEDUA kali hanya
//     untuk membuat occlusion mask; proyek ini punya 400 ribu segitiga rumput,
//     render kedua akan membunuh FPS di HP. Mask dibaca dari buffer kedalaman
//     yang SUDAH ada (hint_depth_texture).
//   - 40 sampel, bukan ~200. Penulis shader aslinya sendiri memperingatkan soal
//     jumlah sampel dan FPS.
//   - Pakai matriks bawaan Godot langsung (lihat catatan di contact_shadows).
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled,
	shadows_disabled, fog_disabled;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec2 source_uv = vec2(0.5);
uniform float aspect = 1.7778;
// Seberapa jauh kabur radial mengular: pecahan jarak piksel ke matahari.
uniform float ray_length = 0.9;
// Ukuran + kelembutan cakram matahari (padanan "Light Source Scale/Feather").
// Cakram besar = shaft panjang; cakram kecil = bercak di dekat matahari saja.
uniform float light_scale = 0.55;
uniform float light_feather = 0.45;
// Dihitung sun_rays.gd setiap frame: memudar di tepi layar dan saat matahari
// berada di belakang kamera.
uniform float strength = 0.0;
const int SAMPLE_COUNT = 40;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float rays = 0.0;
	// Hanya langit: sinar tidak boleh mencuci karakter atau medan.
	if (texture(depth_tex, SCREEN_UV).r < 0.00001 && strength > 0.0) {
		vec2 to_sun = source_uv - SCREEN_UV;
		float span = length(to_sun);
		vec2 dir = span > 0.0001 ? to_sun / span : vec2(0.0);
		float decay = 1.0;
		for (int i = 1; i <= SAMPLE_COUNT; i++) {
			// Sampel tersebar sampai ray_length kali jarak piksel ke matahari,
			// jadi shaft muncul untuk piksel yang JAUH dari matahari juga.
			vec2 uv = SCREEN_UV + dir * span * ray_length
				* (float(i) / float(SAMPLE_COUNT));
			float sky = step(texture(depth_tex, uv).r, 0.00001);
			// Cakram matahari: sampel di dekat sumber paling terang, tapi
			// separuh bobotnya tetap ikut supaya shaft memanjang.
			float dist = length((uv - source_uv) * vec2(aspect, 1.0));
			float disk = 1.0 - smoothstep(light_scale * (1.0 - light_feather),
				light_scale, dist);
			rays += sky * mix(disk, 1.0, 0.5) * decay;
			decay *= 0.97;
		}
	}
	ALBEDO = vec3(1.0, 0.82, 0.58);
	ALPHA = rays * strength / float(SAMPLE_COUNT);
}
