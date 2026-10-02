shader_type spatial;
render_mode diffuse_burley, specular_disabled;
// Permukaan padang 100 m: rumput pastel terang dengan variasi pola, tanpa jalan/arena.
// Tekstur meadow_cover dari Quaternius Stylized Nature MegaKit (CC0);
// atribusi lengkap ada di project/licenses/LICENSES.txt.

uniform sampler2D meadow_cover : filter_linear_mipmap, repeat_enable;
uniform vec4 grass_color : source_color = vec4(0.561, 0.808, 0.388, 1.0);
uniform vec4 grass_dark : source_color = vec4(0.353, 0.627, 0.271, 1.0);
uniform vec4 edge_color : source_color = vec4(0.725, 0.604, 0.420, 1.0);
uniform float half_size = 50.0;
uniform float edge_begin = 45.5;
uniform bool cover_enabled = true;

varying vec3 world_position;

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
	ROUGHNESS = 1.0;
}
