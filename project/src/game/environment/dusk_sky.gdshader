shader_type sky;
// Langit MALAM: zenith biru tua, bintang bersemayam yang berkelip pelan, bulan
// purnama bercratere dengan halo, dan awan tipis gelap yang disinari bulan.
//
// Semua prosedural, tanpa tekstur sama sekali:
//   - bintang = grid hash di koordinat bola langit (azimut/polar), satu bintang
//     per sel di posisi acak yang tetap, jadi tidak ada pola berulang;
//   - kawah bulan = lingkaran analitik di basis lokal piringan bulan;
//   - halo bulan = pow() sudut pandang, tanpa satu pun sampel tambahan.
//
// Arah "sun_direction" sekarang menunjuk ke BULAN (cahaya utama malam). Namanya
// dibiarkan karena dipakai bersama oleh air, pemandangan, dan tes render.
//
// Warna sengaja gelap TAPI tidak hitam pekat: janji test_dusk adalah langit malam
// tetap biru dan tanah tetap terbaca — bukan kegelapan total.

uniform vec3 sun_direction = vec3(-0.73, 0.64, -0.25);

// --- bulan -----------------------------------------------------------------
uniform bool moon_enabled = true;
uniform vec4 moon_color : source_color = vec4(1.0, 0.97, 0.90, 1.0);
uniform float moon_radius = 0.045;
// HDR (> 1) supaya bulan mekar sedikit di glow engine, bukan cakram kertas.
uniform float moon_brightness = 2.4;

// --- bintang ---------------------------------------------------------------
uniform bool stars_enabled = true;
uniform vec4 star_color : source_color = vec4(0.82, 0.88, 1.00, 1.0);
uniform float star_density = 42.0;
// Pecahan sel yang berisi bintang; makin kecil makin jarang.
uniform float star_amount = 0.045;
// Ukuran bintang sebagai pecahan sel (sekitar 1-3 piksel di HP).
uniform float star_size = 0.30;
uniform float star_brightness = 1.7;
uniform float star_twinkle = 0.30;

// --- gradien + awan --------------------------------------------------------
uniform vec4 zenith_color : source_color = vec4(0.010, 0.017, 0.042, 1.0);
uniform vec4 middle_color : source_color = vec4(0.024, 0.037, 0.078, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.055, 0.074, 0.125, 1.0);
uniform vec4 glow_color : source_color = vec4(0.40, 0.55, 0.88, 1.0);
uniform bool glow_enabled = true;
uniform bool clouds_enabled = true;
uniform float cloud_coverage = 0.46;
uniform float cloud_softness = 0.20;
uniform float cloud_scale = 2.4;
// Awan malam: sisi atas kena bulan (abu kebiruan), sisi bawah biru sangat tua.
uniform vec4 cloud_light : source_color = vec4(0.34, 0.40, 0.56, 1.0);
uniform vec4 cloud_shadow : source_color = vec4(0.030, 0.042, 0.075, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Hash dengan koordinat dibungkus: grid bintang memakai angka sampai ± ratusan,
// dan sin() float 32-bit kehilangan presisi di angka segitu (hasilnya belang).
float wrapped_hash(vec2 p) {
	return hash(mod(p, vec2(128.0)));
}

// Nilai noise + fbm: cukup untuk awan lembut, jauh lebih murah dari texture noise.
float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	vec2 smooth_local = local * local * (3.0 - 2.0 * local);
	float a = hash(cell);
	float b = hash(cell + vec2(1.0, 0.0));
	float c = hash(cell + vec2(0.0, 1.0));
	float d = hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, smooth_local.x), mix(c, d, smooth_local.x), smooth_local.y);
}

// Dua tingkat: 4 oktav untuk bentuk awan, 2 oktav untuk bayangannya. Langit
// menutupi sebagian besar layar, jadi jumlah sin() di sini menentukan FPS di HP.
float fbm4(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		total += value_noise(p) * amplitude;
		p *= 2.03;
		amplitude *= 0.5;
	}
	return total;
}

float fbm2(vec2 p) {
	return value_noise(p) * 0.5 + value_noise(p * 2.03) * 0.25;
}

// Bintang: grid di koordinat bola langit. Sumbu azimut keliling (2x lebih
// panjang), jadi skala sumbu polar digandakan supaya sel tetap mendekati persegi
// dan bintang tidak jadi oval.
vec3 star_field(vec3 direction, float fade) {
	vec2 sphere = vec2(atan(direction.z, direction.x),
		acos(clamp(direction.y, -1.0, 1.0)));
	vec2 grid = vec2(sphere.x * star_density, sphere.y * star_density * 2.0);
	vec2 cell = floor(grid);
	vec2 local = fract(grid);
	float presence = wrapped_hash(cell);
	vec2 offset = vec2(wrapped_hash(cell + 17.3), wrapped_hash(cell + 41.9));
	float away = length(local - offset);
	float point = 1.0 - smoothstep(0.0, star_size, away);
	float bright = wrapped_hash(cell + 5.7);
	float twinkle = 1.0 - star_twinkle * 0.5 * (1.0 + sin(TIME * 1.7 + bright * 39.0));
	float on = stars_enabled ? 1.0 : 0.0;
	float lit = step(1.0 - star_amount, presence) * on;
	return star_color.rgb * star_brightness * point * twinkle * fade * lit
		* (0.55 + bright * 0.9);
}

// Bulan + halo. Kawah ditaruh di basis lokal piringan bulan supaya posisinya
// tidak ikut berputar kalau arah bulan diubah.
vec3 moon_disc(vec3 direction) {
	vec3 to_moon = normalize(sun_direction);
	float alignment = dot(direction, to_moon);
	float angle = acos(clamp(alignment, -1.0, 1.0));
	float edge = 1.0 - smoothstep(moon_radius * 0.97, moon_radius * 1.03, angle);
	vec3 reference = abs(to_moon.y) > 0.99 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(reference, to_moon));
	vec3 upward = cross(to_moon, right);
	vec2 local = vec2(dot(direction, right), dot(direction, upward)) / moon_radius;
	float radius = length(local);
	// Enam kawah analitik: posisi dan ukuran dari hash, jadi bentuknya tetap
	// setiap frame (tidak berisik) tapi tidak terlihat seperti lingkaran susun.
	float craters = 0.0;
	for (int i = 0; i < 6; i++) {
		float index = float(i) + 1.0;
		vec2 centre = (vec2(wrapped_hash(vec2(index, 1.7)),
			wrapped_hash(vec2(index, 5.3))) - 0.5) * 1.45;
		float size = 0.09 + wrapped_hash(vec2(index, 9.1)) * 0.20;
		float depth = wrapped_hash(vec2(index, 13.7));
		float fall = 1.0 - smoothstep(size * 0.5, size, length(local - centre));
		craters += fall * (0.30 + depth * 0.45);
	}
	craters = clamp(craters, 0.0, 1.0);
	// Tepi bulan agak gelap (limb darkening) supaya terlihat bulat, bukan stiker.
	float limb = 1.0 - 0.30 * smoothstep(0.5, 1.0, radius);
	vec3 surface = moon_color.rgb * moon_brightness * limb * (1.0 - craters * 0.55);
	// Halo: satu cincin rapat (± 1 jari-jari bulan) + satu lembar lebar (± 30
	// derajat), keduanya memudar halus ke tepi.
	float tight = pow(max(alignment, 0.0), 460.0);
	float wide = pow(max(alignment, 0.0), 18.0);
	vec3 halo = glow_color.rgb * (tight * 0.50 + wide * 0.12);
	float on = moon_enabled ? 1.0 : 0.0;
	float glow_on = glow_enabled ? 1.0 : 0.0;
	return surface * edge * on + halo * glow_on * on;
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	float elevation = max(direction.y, 0.0);
	vec3 moon = normalize(sun_direction);
	// Gradien malam: ufuk paling terang (sisa cahaya), zenith paling gelap.
	vec3 color = mix(horizon_color.rgb, middle_color.rgb,
		smoothstep(0.0, 0.26, elevation));
	color = mix(color, zenith_color.rgb, smoothstep(0.20, 0.78, elevation));
	// Bintang memudar dekat ufuk: di dunia nyata atmosfer menelan bintang yang
	// rendah, dan tanpa ini bintang terlihat "menempel" di garis pantai.
	color += star_field(direction, smoothstep(0.0, 0.20, elevation));
	color += moon_disc(direction);
	if (clouds_enabled) {
		// Awan diproyeksikan ke satu bidang datar di atas kepala lalu diregangkan
		// mendatar, jadi bentuknya pita panjang seperti sebelumnya.
		vec2 plane = direction.xz / max(elevation, 0.05) * cloud_scale;
		plane.x *= 0.55;
		plane += vec2(TIME * 0.006, TIME * 0.0025);
		float shape = fbm4(plane * 0.5);
		float clouds = smoothstep(cloud_coverage - cloud_softness,
			cloud_coverage + cloud_softness, shape);
		float lit = fbm2(plane * 0.85 + vec2(3.7, 1.3));
		vec3 tint = mix(cloud_shadow.rgb, cloud_light.rgb, smoothstep(0.30, 0.72, lit));
		// Awan yang lewat di depan bulan disinari bulan dari belakang.
		float moonlit = pow(max(dot(direction, moon), 0.0), 6.0);
		tint = mix(tint, glow_color.rgb * 0.55, moonlit * 0.45);
		// Awan hanya di atas ufuk, memudar sebelum horizon.
		float mask = smoothstep(0.015, 0.14, elevation) * (1.0 - smoothstep(0.72, 1.0, elevation) * 0.25);
		color = mix(color, tint, clouds * mask * 0.92);
	}
	COLOR = color;
}
