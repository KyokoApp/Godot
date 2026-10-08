shader_type sky;
// Langit MALAM: zenith biru tua, bintang berkelip, dan bulan purnama bercratere
// dengan halo. TIDAK ADA AWAN — diminta pengguna ("terlalu rame banget itu
// awannya ilangin"), dan membuangnya juga menghemat banyak FPS: awan dulu memakai
// fbm 4 oktav + 2 oktav (± 24 pemanggilan sin() per piksel) di layar penuh.
//
// Semua prosedural, tanpa tekstur:
//   - bintang = grid hash di koordinat bola langit (azimut/polar), satu bintang
//     per sel di posisi acak yang tetap, jadi tidak ada pola berulang;
//   - kawah bulan = lingkaran analitik di basis lokal piringan bulan;
//   - halo bulan = exp() sudut pandang.
//
// Hemat FPS (tetap dipertahankan): bintang hanya dihitung di atas ufuk (cabang
// dinamis), dan kawah bulan hanya dihitung di dekat piringan. Yang TIDAK
// dihemat lagi: hash bintang kembali jadi 3 pemanggilan terpisah — versi 1 hash
// bikin posisi bintang berpola garis dan bentuknya oval (ditolak pengguna).
//
// Arah "sun_direction" menunjuk ke BULAN. Namanya dibiarkan karena dipakai
// bersama oleh air, pemandangan, dan tes render.

uniform vec3 sun_direction = vec3(-0.91, 0.26, -0.31);

// --- bulan -----------------------------------------------------------------
uniform bool moon_enabled = true;
uniform vec4 moon_color : source_color = vec4(1.0, 0.97, 0.90, 1.0);
uniform float moon_radius = 0.045;
// HDR (> 1) supaya bulan mekar sedikit di glow engine, bukan cakram kertas.
uniform float moon_brightness = 1.8;

// --- bintang ---------------------------------------------------------------
uniform bool stars_enabled = true;
uniform vec4 star_color : source_color = vec4(0.82, 0.88, 1.00, 1.0);
uniform float star_density = 34.0;
// Pecahan sel yang berisi bintang. Dikurangi dari 0,045: permintaan pengguna
// "bintang nya buat lebih sedikit jangan terlalu rame".
uniform float star_amount = 0.016;
// Ukuran INTI bintang dalam sel polar (1 sel polar = 1/(2*star_density) radian).
// Sengaja kecil: bintang asli intinya nyaris sebesar piksel, dan ukuran seragam
// yang besar bikin terlihat seperti sprite PNG tempel (keluhan pengguna).
// Cahayanya tetap penuh di tengah, jadi bintang tetap terlihat walau intinya
// hanya satu-dua piksel — sisanya ditangani halo lembut di star_field().
uniform float star_size = 0.30;
uniform float star_brightness = 1.7;
uniform float star_twinkle = 0.30;

// --- gradien ---------------------------------------------------------------
// Nilai ini JAUH di atas hasil tonemap: tonemap filmik menekan nilai kecil sekali
// (terukur: 0,017 linear -> 0,0078 di layar), jadi biru harus ditulis lebih tinggi
// supaya zenith tetap terbaca biru dan tidak jadi hitam.
uniform vec4 zenith_color : source_color = vec4(0.022, 0.038, 0.095, 1.0);
uniform vec4 middle_color : source_color = vec4(0.042, 0.062, 0.135, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.085, 0.110, 0.190, 1.0);
uniform vec4 glow_color : source_color = vec4(0.40, 0.55, 0.88, 1.0);
uniform bool glow_enabled = true;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Hash dengan koordinat dibungkus: grid bintang memakai angka sampai ± ratusan,
// dan sin() float 32-bit kehilangan presisi di angka segitu (hasilnya belang).
float wrapped_hash(vec2 p) {
	return hash(mod(p, vec2(128.0)));
}

// Bintang: grid di koordinat bola langit. Sumbu azimut keliling (2x lebih
// panjang), jadi skala sumbu polar digandakan supaya jumlah sel di kedua arah
// seimbang.
//
// DUA hal yang bikin langit terlihat "kayak PNG" dan sudah diperbaiki di sini:
//   1. Sel azimut selebar 2x sel polar DALAM SUDUT. Jarak ke pusat bintang harus
//      dikoreksi (x dikali 2) sebelum dibandingkan dengan star_size — tanpa itu
//      setiap bintang jadi oval horizontal dan langit penuh garis-garis.
//   2. Offset posisi dan kecerahan pakai hash TERPISAH. Versi hemat yang
//      menurunkan keduanya dari SATU hash membuat posisi bintang terkurung di
//      satu kurva, jadi pola grid-nya tetap kelihatan.
vec3 star_field(vec3 direction, float fade) {
	vec2 sphere = vec2(atan(direction.z, direction.x),
		acos(clamp(direction.y, -1.0, 1.0)));
	vec2 grid = vec2(sphere.x * star_density, sphere.y * star_density * 2.0);
	vec2 cell = floor(grid);
	vec2 local = fract(grid);
	vec2 wrapped = mod(cell, vec2(128.0));
	float roll = hash(wrapped);
	vec2 offset = vec2(hash(wrapped + 17.3), hash(wrapped + 41.9));
	// Koreksi aspek sel: satu sel azimut = 2 sel polar dalam sudut.
	float away = length((local - offset) * vec2(2.0, 1.0));
	float bright = hash(wrapped + 5.7);
	// Distribusi magnitudo seperti langit sungguhan: kebanyakan redup, sedikit
	// yang terang (pow mendorong ke angka kecil). Bintang terang juga lebih besar.
	float magnitude = pow(bright, 2.6);
	float reach = away / (0.45 + magnitude * 1.55);
	// Titik tajam + halo lembut. Bintang asli bukan cakram datar: intinya nyaris
	// sebesar piksel, dan yang bikin terasa "langit" adalah glow di sekitarnya.
	float core = 1.0 - smoothstep(0.0, star_size, reach);
	float halo = exp(-reach * reach * 30.0) * 0.28;
	float twinkle = 1.0 - star_twinkle * 0.5 * (1.0 + sin(TIME * 1.7 + bright * 39.0));
	float on = stars_enabled ? 1.0 : 0.0;
	float lit = step(1.0 - star_amount, roll) * on;
	// Sedikit variasi warna: biru dingin sampai kuning hangat.
	vec3 tint = mix(vec3(0.70, 0.81, 1.0), vec3(1.0, 0.87, 0.70), fract(bright * 7.31));
	return star_color.rgb * tint * star_brightness * (core + halo) * (0.30 + magnitude * 2.6)
		* twinkle * fade * lit;
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
	// HEMAT: hanya dihitung di dekat piringan — bulan kecil, jadi mayoritas
	// piksel langsung melewati enam hash ini.
	float craters = 0.0;
	if (angle < moon_radius * 1.7) {
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
	}
	// Tepi bulan agak gelap (limb darkening) supaya terlihat bulat, bukan stiker.
	float limb = 1.0 - 0.30 * smoothstep(0.5, 1.0, radius);
	vec3 surface = moon_color.rgb * moon_brightness * limb * (1.0 - craters * 0.55);
	// Halo: cincin rapat (± 1 jari-jari bulan) + lembar lebar ± 30 derajat.
	// Bentuk lama memakai pow(cos(angle), 460/18); exp() sudut memberi bentuk
	// yang sama dengan harga satu operasi, bukan log + exp.
	// HEMAT: cincin rapat hanya dihitung kalau sudutnya masih masuk.
	float tight = 0.0;
	if (angle < 0.25) {
		tight = exp(-angle * angle * 260.0);
	}
	float wide = exp(-angle * angle * 12.0);
	vec3 halo = glow_color.rgb * (tight * 0.50 + wide * 0.12);
	float on = moon_enabled ? 1.0 : 0.0;
	float glow_on = glow_enabled ? 1.0 : 0.0;
	return surface * edge * on + halo * glow_on * on;
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	float elevation = max(direction.y, 0.0);
	// Gradien malam: ufuk paling terang (sisa cahaya), zenith paling gelap.
	vec3 color = mix(horizon_color.rgb, middle_color.rgb,
		smoothstep(0.0, 0.26, elevation));
	color = mix(color, zenith_color.rgb, smoothstep(0.20, 0.78, elevation));
	// Bintang memudar dekat ufuk: di dunia nyata atmosfer menelan bintang yang
	// rendah, dan tanpa ini bintang terlihat "menempel" di garis pantai. Cabang
	// dinamis: setengah bawah layar (tanah/pantai) tidak menghitung bintang sama
	// sekali — itu hemat FPS terbesar setelah awan dibuang.
	if (elevation > 0.03) {
		color += star_field(direction, smoothstep(0.03, 0.22, elevation));
	}
	color += moon_disc(direction);
	// Dither halus (± setengah level 8-bit). Gradasi biru TUA kalau dibulatkan
	// langsung jadi garis-garis horizontal (banding) — itu yang bikin langit
	// terlihat "kayak PNG". Butir ini memecah garisnya tanpa terlihat sebagai
	// noise. Diambil dari arah pandang supaya tetap stabil per piksel.
	COLOR = color + (hash(direction.xy * 733.0 + direction.z) - 0.5) * 0.005;
}
