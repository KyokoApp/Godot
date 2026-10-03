shader_type spatial;
render_mode diffuse_burley, specular_disabled;
// Permukaan pulau 500 m: rumput pastel dengan variasi pola + jalan tanah
// berliku seperti di ilustrasi layar muat. Jalan digambar di shader (bukan mesh
// terpisah) supaya tidak ada collision/tambahan draw call: pemain tetap berjalan
// di medan yang sama.
// Tekstur meadow_cover dari Quaternius Stylized Nature MegaKit (CC0);
// atribusi lengkap ada di project/licenses/LICENSES.txt.
//
// Batas pulau tidak lagi kotak: garis pantainya bergelombang, jadi "tepi" tidak
// bisa dihitung dari jarak ke pusat. Yang dipakai adalah KETINGGIAN titik itu
// sendiri (world_position.y) — tanah yang tingginya mendekati permukaan laut
// adalah pantai, di mana pun letaknya.

uniform sampler2D meadow_cover : filter_linear_mipmap, repeat_enable;
uniform vec4 grass_color : source_color = vec4(0.561, 0.808, 0.388, 1.0);
uniform vec4 grass_dark : source_color = vec4(0.353, 0.627, 0.271, 1.0);
uniform vec4 sand_color : source_color = vec4(0.788, 0.659, 0.451, 1.0);
uniform bool cover_enabled = true;
uniform vec4 path_color : source_color = vec4(0.788, 0.659, 0.451, 1.0);
uniform float path_width = 3.0;
uniform float path_curve = 24.0;
uniform float path_frequency = 0.021;
uniform bool path_enabled = true;
// Pita pasir: di rentang ketinggian ini di atas permukaan laut, tanah berubah
// jadi pasir. Angkanya mengikuti tanjakan pantai di field.gd.
uniform float shore_low = 0.35;
uniform float shore_high = 2.6;

varying vec3 world_position;

void vertex() {
	// Tanpa baris ini `world_position` selalu nol: pola rumput, pita pantai, dan
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
	// Pantai: tanah yang tingginya mendekati permukaan laut jadi pasir. Karena
	// memakai ketinggian, pita ini mengikuti garis pantai yang bergelombang
	// tanpa perlu tahu bentuk pulainya.
	float shore = 1.0 - smoothstep(shore_low, shore_high, world_position.y);
	ALBEDO = mix(land, land * COLOR.rgb, 0.55);
	ALBEDO = mix(ALBEDO, sand_color.rgb, shore * 0.92);
	// Jalan berliku: jarak ke kurva z = curve * sin(x * frequency), dilebarkan
	// sedikit oleh noise supaya tepinya tidak terlihat seperti hasil rumus.
	if (path_enabled) {
		// Dua gelombang supaya jalannya berkeluk tidak berulang; fasa 0,59
		// Angka fasa dipilih agar jalan melintas TEPAT di titik muncul pemain
		// (0, 7): path_centre(0) = 6,99 m. Angkanya harus SAMA dengan
		// Field.path_centre() di field.gd, kalau berbeda rumput tumbuh di jalan.
		float centre = path_curve * sin(world_position.x * path_frequency)
			+ path_curve * 0.3 * sin(world_position.x * 0.033 + 1.33);
		float wobble = (fine - 0.5) * 1.1;
		float distance_to_path = abs(world_position.z - centre) + wobble;
		float path = 1.0 - smoothstep(path_width * 0.55, path_width * 1.25,
			distance_to_path);
		float grit = mix(0.88, 1.06, broad);
		ALBEDO = mix(ALBEDO, path_color.rgb * grit, path * 0.92);
	}
	ROUGHNESS = 1.0;
}
