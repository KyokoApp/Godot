shader_type spatial;
render_mode diffuse_burley, specular_disabled;
// Tekstur tanah mengulang di koordinat dunia, jadi lempeng visual bisa berpindah
// tanpa sambungan warna atau pola yang ikut bergeser.

uniform sampler2D meadow_cover : filter_linear_mipmap, repeat_enable;
uniform vec3 grass_dark : source_color = vec3(0.176, 0.310, 0.153);
uniform vec3 grass_light : source_color = vec3(0.247, 0.420, 0.204);

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fine = texture(meadow_cover, world_position.xz * 0.10).r;
	float broad = texture(meadow_cover, world_position.xz * 0.022).g;
	vec3 land = mix(grass_dark, grass_light, fine);
	land *= 0.93 + 0.14 * broad;
	ALBEDO = land;
	ROUGHNESS = 1.0;
}
