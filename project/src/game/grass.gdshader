shader_type spatial;
render_mode cull_disabled, world_vertex_coords, diffuse_burley, specular_disabled;
// Adaptasi CC0 @_Malido / Malidos: Stylized Multimesh Grass Shader.
// Sumber dan perubahan tercatat di docs/CREDITS.md.
// Mesh buatan proyek: UV.y = 1 di akar dan 0 di ujung.

uniform vec3 top_color : source_color = vec3(0.38, 0.65, 0.24);
uniform vec3 bottom_color : source_color = vec3(0.29, 0.53, 0.19);
uniform sampler2D wind_noise : repeat_enable, filter_linear;
uniform vec3 player_position = vec3(0.0);
uniform vec2 wind_direction = vec2(0.8, 0.4);
uniform float wind_strength = 0.20;
uniform float fade_start = 16.0;
uniform float fade_end = 23.0;

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float tip = 1.0 - UV.y;
	float distance_xz = length(root.xz - player_position.xz);
	float visibility = 1.0 - smoothstep(fade_start, fade_end, distance_xz);
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
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec3 color = mix(bottom_color, top_color, 1.0 - UV.y);
	ALBEDO = mix(color, bottom_color * 0.95, pow(UV.y, 5.0));
	ROUGHNESS = 1.0;
	// Godot membalik normal backface sebelum fragment ketika cull_disabled.
	// Tetapkan world-up dalam VIEW space di sini, bukan hanya pada vertex:
	// kedua sisi menerima cahaya matahari yang sama, tanpa bidang hitam.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
