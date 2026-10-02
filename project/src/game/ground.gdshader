shader_type spatial;
render_mode diffuse_burley, specular_disabled;
// Permukaan padang 100 m: rumput pastel terang dengan variasi pola + jalan tanah
// berliku seperti di ilustrasi layar muat. Jalan digambar di shader (bukan mesh
// terpisah) supaya tidak ada collision/tambahan draw call: pemain tetap berjalan
// di medan yang sama.
// Tekstur meadow_cover dari Quaternius Stylized Nature MegaKit (CC0);
// atribusi lengkap ada di project/licenses/LICENSES.txt.

uniform sampler2D meadow_cover : filter_linear_mipmap, repeat_enable;
uniform vec4 grass_color : source_color = vec4(0.561, 0.808, 0.388, 1.0);
uniform vec4 grass_dark : source_color = vec4(0.353, 0.627, 0.271, 1.0);
uniform vec4 edge_color : source_color = vec4(0.725, 0.604, 0.420, 1.0);
uniform float half_size = 50.0;
uniform float edge_begin = 45.5;
uniform bool cover_enabled = true;
uniform vec4 path_color : source_color = vec4(0.788, 0.659, 0.451, 1.0);
uniform float path_width = 2.1;
uniform float path_curve = 14.0;
uniform float path_frequency = 0.085;
uniform bool path_enabled = true;

varying vec3 world_position;

void vertex() {
	// Tanpa baris ini `world_position` selalu nol: pola rumput, cincin tepi, dan
	// jalan berliku semuanya membaca satu titik yang sama (tanah jadi rata satu
	// warna). Varying ditulis di vertex(), dibaca di fragment().
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fine = 0.5;
	float broad = 0.5;
	if (cover_enabled) {
		fine = texture(meadow_cover, world_position.xz * 0.10).r;
		broad = texture(meadow_cover, world_position.xz * 0.022).g;
	}
	vec3 land = mix(grass_dark.rgb, grass_color.rgb, fine);
	land *= 0.93 + 0.14 * broad;
	// Tepi padang menghitam lembut ke arah pagar supaya batas 100 m terbaca.
	float edge = max(abs(world_position.x), abs(world_position.z));
	float ring = smoothstep(edge_begin, half_size, edge);
	ALBEDO = mix(land, land * COLOR.rgb, 0.55);
	ALBEDO = mix(ALBEDO, edge_color.rgb, ring * 0.85);
	// Jalan berliku: jarak ke kurva z = curve * sin(x * frequency), dilebarkan
	// sedikit oleh noise supaya tepinya tidak terlihat seperti hasil rumus.
	if (path_enabled) {
		float centre = path_curve * sin(world_position.x * path_frequency)
			+ path_curve * 0.35 * sin(world_position.x * 0.031 + 1.7);
		float wobble = (fine - 0.5) * 1.1;
		float distance_to_path = abs(world_position.z - centre) + wobble;
		float path = 1.0 - smoothstep(path_width * 0.55, path_width * 1.25,
			distance_to_path);
		float grit = mix(0.88, 1.06, broad);
		ALBEDO = mix(ALBEDO, path_color.rgb * grit, path * 0.92);
	}
	ROUGHNESS = 1.0;
}
