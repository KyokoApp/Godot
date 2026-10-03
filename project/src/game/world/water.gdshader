shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
// Air berbentuk gelombang, dipakai untuk laut sekaligus kolam tengah.
// Dasar ide dari shader "Simple Water" (dairycultist, godotshaders.com, CC0):
//   * gelombang digerakkan di vertex + normal dihitung dari tetangganya,
//   * transparansi jatuh menurut KEDALAMAN: yang cetek tembus pandang, yang
//     dalam makin buram.
// Dua hal diubah supaya cocok di sini:
//   1. sampler3D Noise diganti gelombang sinus analitik (tiga gelombang
//      berjalan) — tidak butuh tekstur 3D dan tetap murah.
//   2. Ditambah pantulan: METALLIC tinggi + ROUGHNESS rendah membuat air
//      memantulkan langit malam dan bulan lewat Environment bawaan (renderer
//      Mobile tidak punya SSR), plus kilau specular dari arah bulan.
// Warna biru rendah saturasi seperti saran shader aslinya.
//
// PENTING (ronde 18): normal riak dihitung ULANG di fragment(), bukan cuma
// dipotong dari vertex. Laut selebar 900 m cuma punya sel ~9 m; kalau normal
// hanya dihitung di vertex, riaknya rata dalam satu sel dan air terlihat
// seperti kaca. Dengan turunan analitik di fragment, riak tetap terlihat di
// sepanjang pantai tanpa perlu memecah mesh jadi jutaan segitiga.

uniform vec4 deep_color : source_color = vec4(0.012, 0.040, 0.085, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.055, 0.135, 0.200, 1.0);
uniform vec4 sun_color : source_color = vec4(0.62, 0.74, 0.98, 1.0);
// Arah bulan (15 derajat, barat daya); dikirim dari main.gd supaya angka di
// layar dan di gambar tes sama.
uniform vec3 sun_direction = vec3(-0.91, 0.26, -0.31);
// Tinggi gelombang (meter). Laut boleh lebih besar dari kolam.
uniform float wave_height = 0.10;
// Panjang gelombang (meter). Semakin besar semakin landai riaknya.
uniform float wave_length = 7.0;
// Kecepatan gelombang.
uniform float wave_speed = 0.7;
// Kedalaman (meter) tempat air jadi buram penuh. Di bawah ini tembus pandang.
uniform float depth_fade = 2.5;
// Seberapa dalam air sebelum benar-benar tak tembus.
uniform float depth_full = 6.0;
// Kekuatan pantulan langit (0..1).
uniform float reflectivity = 0.85;
uniform float horizon_fade = 420.0;
// Godot 4.5: DEPTH_TEXTURE tidak lagi jadi bawaan. Tanpa baris ini shader
// GAGAL kompilasi ("DEPTH_TEXTURE has been removed in favor of using
// hint_depth_texture") — dan karena pond.gd mem-preload shader yang sama,
// kegagalan itu ikut mematikan Pond.new() di main.gd.
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

varying vec3 world_position;

// Tiga gelombang berjalan: arah, panjang, dan amplitudo masing-masing.
// Arah sudah ternormalisasi supaya k bisa langsung dipakai sebagai kemiringan.
const vec3 WAVE_A = vec3(0.943, 0.330, 1.0);
const vec3 WAVE_B = vec3(-0.514, 0.857, 0.6);
const vec3 WAVE_C = vec3(0.664, -0.747, 0.35);

// Tinggi permukaan air di titik (x, z) pada waktu `time`.
float wave_height_at(vec2 p, float time) {
	float h = 0.0;
	h += sin(dot(p, WAVE_A.xy) * (6.2831853 / wave_length) - time * wave_speed) * WAVE_A.z;
	h += sin(dot(p, WAVE_B.xy) * (6.2831853 / (wave_length * 0.63)) - time * wave_speed * 1.4) * WAVE_B.z;
	h += sin(dot(p, WAVE_C.xy) * (6.2831853 / (wave_length * 0.41)) - time * wave_speed * 1.9) * WAVE_C.z;
	return h / 1.95 * wave_height;
}

// Kemiringan permukaan (dh/dx, dh/dz): turunan analitik dari wave_height_at.
// Dihitung sekali dan dipakai bersama tinggi air, jadi riak di layar sama
// persis dengan riak yang menggerakkan mesh-nya.
vec2 wave_slope_at(vec2 p, float time) {
	vec2 slope = vec2(0.0);
	float ka = 6.2831853 / wave_length;
	float kb = 6.2831853 / (wave_length * 0.63);
	float kc = 6.2831853 / (wave_length * 0.41);
	slope += cos(dot(p, WAVE_A.xy) * ka - time * wave_speed) * WAVE_A.z * ka * WAVE_A.xy;
	slope += cos(dot(p, WAVE_B.xy) * kb - time * wave_speed * 1.4) * WAVE_B.z * kb * WAVE_B.xy;
	slope += cos(dot(p, WAVE_C.xy) * kc - time * wave_speed * 1.9) * WAVE_C.z * kc * WAVE_C.xy;
	return slope / 1.95 * wave_height;
}

void vertex() {
	vec4 world = MODEL_MATRIX * vec4(VERTEX, 1.0);
	world_position = world.xyz;
	VERTEX.y += wave_height_at(world_position.xz, TIME);
}

void fragment() {
	// --- Kedalaman: bandingkan kedalaman layar (dasar) dengan kedalaman air ---
	float scene_depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	vec3 scene_ndc = vec3(SCREEN_UV * 2.0 - 1.0, scene_depth);
	vec4 scene_view = INV_PROJECTION_MATRIX * vec4(scene_ndc, 1.0);
	scene_view.xyz /= scene_view.w;
	float bottom = -scene_view.z;

	float object_depth = FRAGCOORD.z;
	vec3 object_ndc = vec3(SCREEN_UV * 2.0 - 1.0, object_depth);
	vec4 object_view = INV_PROJECTION_MATRIX * vec4(object_ndc, 1.0);
	object_view.xyz /= object_view.w;
	float surface = -object_view.z;

	// 0 = tepat di dasar (sangat cetek), 1 = se dalam depth_full.
	float thickness = clamp((bottom - surface) / max(depth_full - depth_fade, 0.001), 0.0, 1.0);
	float shallow = 1.0 - smoothstep(depth_fade, depth_full, bottom - surface);

	vec3 water = mix(shallow_color.rgb, deep_color.rgb, thickness);
	// Warna dasar ikut terlihat saat air cetek — itu yang membuat kolam terbaca
	// cetek, bukan seperti cat biru.
	water = mix(shallow_color.rgb * 1.35, water, shallow * 0.75 + 0.25);

	ALBEDO = water;
	METALLIC = reflectivity;
	ROUGHNESS = 0.06;
	SPECULAR = 1.0;
	// Air cetek jauh lebih tembus pandang: dasarnya masih terlihat. Pembagi
	// memakai depth_full (bukan depth_fade) supaya kolam 0,9 m tidak langsung
	// jadi buram penuh — kalau memakai depth_fade, kolam cetek terbaca seperti
	// cat biru dan dasarnya tidak kelihatan.
	ALPHA = mix(0.30, 1.0, clamp((bottom - surface) / depth_full, 0.0, 1.0));

	// RiaK: normal dari turunan analitik gelombang yang sama (per piksel, jadi
	// tetap terlihat walau sel mesh air selebar 9 m).
	vec2 slope = wave_slope_at(world_position.xz, TIME);
	NORMAL = normalize(vec3(-slope.x, 1.0, -slope.y));

	// Kilau bulan di air, mengikuti riak.
	vec3 view_dir = normalize(world_position - CAMERA_POSITION_WORLD);
	float glint = pow(max(dot(view_dir, normalize(sun_direction)), 0.0), 90.0);
	EMISSION = sun_color.rgb * glint * 1.2;

	// Garis horizon: laut menyatu dengan langit seperti ilustrasi.
	float distance_fade = 1.0 - smoothstep(horizon_fade * 0.35, horizon_fade,
		length(world_position.xz - CAMERA_POSITION_WORLD.xz));
	ALBEDO = mix(ALBEDO, sun_color.rgb * 0.55 + shallow_color.rgb * 0.45,
		pow(1.0 - distance_fade, 3.0) * 0.4);
}
