shader_type spatial;
render_mode cull_disabled, world_vertex_coords, diffuse_burley, specular_disabled;
// Adaptasi shader rumput untuk vegetasi runtime.
// Sumber, atribusi, lisensi, dan perubahan: project/licenses/LICENSES.txt.
// Mesh buatan proyek: UV.y = 1 di akar dan 0 di ujung.

// Warna helai = warna tanah (field.gd GRASS_COLOR / GRASS_DARK) supaya rumput
// dan tanah terbaca sebagai SATU warna, bukan dua hijau yang berselisih.
// Ujung sedikit lebih terang dari akar: itu yang masih membuat helai terbaca
// sebagai benda 3D setelah warnanya disamakan.
uniform vec3 top_color : source_color = vec3(0.247, 0.420, 0.204);
uniform vec3 bottom_color : source_color = vec3(0.176, 0.310, 0.153);
uniform sampler2D wind_noise : repeat_enable, filter_linear;
uniform vec3 player_position = vec3(0.0);
uniform vec2 wind_direction = vec2(0.8, 0.4);
uniform float wind_strength = 0.20;
uniform float fade_start = 16.0;
uniform float fade_end = 23.0;

varying vec3 grass_world_position;

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float tip = UV.x > 1.5 ? 0.0 : 1.0 - UV.y;
	float distance_xz = length(root.xz - player_position.xz);
	float visibility = 1.0 - smoothstep(fade_start, fade_end, distance_xz);
	// Detail dan lapisan bawah lenyap sebelum batas tile LOD terdekat (12 m).
	if (INSTANCE_CUSTOM.r > 0.5 || UV.x > 1.5) {
		visibility *= 1.0 - smoothstep(8.0, 11.0, distance_xz);
	}
	// Menyusut ke akar secara halus; tetap opaque, tanpa overdraw alpha.
	VERTEX = mix(root, VERTEX, visibility);
	vec2 wind = wind_direction / max(length(wind_direction), 0.001);
	float noise = texture(wind_noise,
		root.xz * 0.045 - wind * (TIME + UV.y / 2.5) * 0.08).r;
	float sway = (noise * 0.75 + sin(TIME * 1.4 + root.x * 0.3) * 0.25);
	vec2 away = root.xz - player_position.xz;
	float horizontal_distance = length(away);
	vec2 push_direction = away / max(horizontal_distance, 0.001);
	float push = (1.0 - smoothstep(0.2, 1.1, horizontal_distance));
	push *= 1.0 - smoothstep(0.8, 1.8, abs(root.y - player_position.y));
	VERTEX.xz += (wind * sway * wind_strength + push_direction * push * 0.40)
		* tip * tip * visibility;
	VERTEX.y -= push * tip * 0.13 * visibility;
	grass_world_position = VERTEX;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec3 color = mix(bottom_color, top_color, 1.0 - UV.y);
	ALBEDO = mix(color, bottom_color * 0.95, pow(UV.y, 5.0));
	if (UV.x > 1.5) {
		// Corak rumput pendek world-space, menyambung antar-rumpun tanpa tekstur alpha.
		float blades = sin(grass_world_position.x * 48.0
			+ sin(grass_world_position.z * 31.0) * 2.0) * 0.5 + 0.5;
		float patches = texture(wind_noise, grass_world_position.xz * 0.18).r;
		ALBEDO = mix(bottom_color, top_color, 0.30 + blades * 0.18 + patches * 0.18);
	}
	ROUGHNESS = 1.0;
	// Godot membalik normal backface sebelum fragment ketika cull_disabled.
	// Tetapkan world-up dalam VIEW space di sini, bukan hanya pada vertex:
	// kedua sisi menerima cahaya matahari yang sama, tanpa bidang hitam.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
