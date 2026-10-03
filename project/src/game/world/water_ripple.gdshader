shader_type spatial;
// Cincin riak di permukaan air danau.
//
// Dipanggil setiap kali kaki pemain menapak air (lihat water_ripple.gd):
// satu bidang datar berbentuk cincin yang MELEBAR dan MEREDAM dari titik
// tapak kaki. Inilah umpan balik visual yang membuat "jalan di atas air"
// terasa seperti air, bukan seperti lantai tak terlihat.
//
// Murah untuk HP: satu quad, tanpa tekstur, tanpa bayangan, aditif. Hanya
// dipakai saat ada langkah di air (pool 8 cincin, sisanya tidur).

render_mode blend_add, cull_disabled, depth_draw_never, unshaded;

uniform vec3 tint : source_color = vec3(0.42, 0.70, 0.95);
// Umur riak dalam detik dan jarak terjauh cincin (meter), diatur dari script.
uniform float age = 0.0;
uniform float life = 1.0;
uniform float radius = 2.0;
// 0..1: langkah pelan kecil, lari/mendarat besar.
uniform float strength = 1.0;

// Posisi dalam bidang air (model space), dipakai untuk jarak dari pusat riak.
varying vec2 local;

void vertex() {
	local = VERTEX.xy;
}

void fragment() {
	float d = length(local) / radius;
	float t = clamp(age / life, 0.0, 1.0);
	// Cincin utama: mula-mula rapat di titik tapak, lalu melebar dan meredam.
	float e = (d - t) / (0.10 + 0.18 * t);
	float ring = exp(-e * e);
	// Cincin kedua yang menyusul: air yang masih bergerak di belakang riak.
	float e2 = (d - t * 0.70) / ((0.10 + 0.18 * t) * 1.8);
	float trail = 0.40 * exp(-e2 * e2);
	// Kilau sesaat tepat di tempat kaki menyentuh air.
	float c = d / 0.25;
	float core = (1.0 - t) * exp(-c * c);
	float fade = 1.0 - t;
	ALBEDO = tint;
	ALPHA = clamp((ring + trail + core * 0.70) * fade * strength, 0.0, 1.0);
}
