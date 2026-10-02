shader_type sky;
// Langit senja seperti ilustrasi layar muat (project/launcher/art/loading.jpg):
// zenith biru lavender, pita hangat krem-persik tepat di atas ufuk barat tempat
// matahari baru terbenam, dan awan tipis panjang yang sisi bawahnya kena cahaya.
//
// Semua warna diambil dari ilustrasi itu (contoh piksel):
//   zenith #7C95CD, tengah #9DB0D6, pita hangat #D1C2CC, pendar ufuk #F7CEC1.
// Tidak ada bulan dan tidak ada bintang: di ilustrasi langitnya bersih, titik
// cahaya yang terlihat adalah kunang-kunang di dekat tanah (lihat world/scenery.gd).

uniform vec3 sun_direction = vec3(-0.94, 0.09, -0.32);
uniform vec4 sun_color : source_color = vec4(1.0, 0.88, 0.74, 1.0);
// Warna senja yang lebih dalam dari siang hari: zenith lavender tua, ufuk
// menghangat ke persik. Angkanya sengaja tidak turun jauh — test_dusk menjamin
// langit tetap TERANG (zenith biru > 0,30), bukan malam pekat.
uniform vec4 zenith_color : source_color = vec4(0.300, 0.420, 0.710, 1.0);
uniform vec4 middle_color : source_color = vec4(0.470, 0.560, 0.800, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.730, 0.690, 0.790, 1.0);
uniform vec4 glow_color : source_color = vec4(0.980, 0.780, 0.700, 1.0);
uniform bool glow_enabled = true;
uniform bool clouds_enabled = true;
uniform float cloud_coverage = 0.46;
uniform float cloud_softness = 0.20;
uniform float cloud_scale = 2.4;
uniform vec4 cloud_light : source_color = vec4(1.0, 0.97, 0.97, 1.0);
uniform vec4 cloud_shadow : source_color = vec4(0.545, 0.573, 0.780, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
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

void sky() {
	vec3 direction = normalize(EYEDIR);
	float elevation = max(direction.y, 0.0);
	vec3 sun = normalize(sun_direction);
	float towards = max(dot(normalize(vec3(direction.x, 0.0, direction.z)),
		normalize(vec3(sun.x, 0.0, sun.z))), 0.0);
	vec3 color = mix(horizon_color.rgb, middle_color.rgb,
		smoothstep(0.0, 0.26, elevation));
	color = mix(color, zenith_color.rgb, smoothstep(0.20, 0.78, elevation));
	// Pita hangat di atas ufuk, paling kuat ke arah matahari yang rendah.
	float band = exp(-pow(elevation * 6.5, 1.15));
	float glow = pow(towards, 2.4) * band;
	if (glow_enabled) {
		color = mix(color, glow_color.rgb, glow * 0.80);
		// Pendar lembut di sekitar matahari (di ilustrasi cakramnya tertutup awan).
		color += sun_color.rgb * glow * 0.22;
		color += sun_color.rgb * pow(max(dot(direction, sun), 0.0), 40.0) * 0.30;
	}
	if (clouds_enabled) {
		// Awan diproyeksikan ke satu bidang datar di atas kepala lalu diregangkan
		// mendatar, jadi bentuknya pita panjang seperti di ilustrasi.
		vec2 plane = direction.xz / max(elevation, 0.05) * cloud_scale;
		plane.x *= 0.55;
		plane += vec2(TIME * 0.006, TIME * 0.0025);
		float shape = fbm4(plane * 0.5);
		float clouds = smoothstep(cloud_coverage - cloud_softness,
			cloud_coverage + cloud_softness, shape);
		float lit = fbm2(plane * 0.85 + vec2(3.7, 1.3));
		vec3 tint = mix(cloud_shadow.rgb, cloud_light.rgb, smoothstep(0.30, 0.72, lit));
		// Sisi bawah awan kena cahaya matahari yang rendah.
		tint = mix(tint, glow_color.rgb, glow * 0.6);
		// Awan hanya di atas ufuk, memudar sebelum horizon.
		float mask = smoothstep(0.015, 0.14, elevation) * (1.0 - smoothstep(0.72, 1.0, elevation) * 0.25);
		color = mix(color, tint, clouds * mask * 0.92);
	}
	COLOR = color;
}
