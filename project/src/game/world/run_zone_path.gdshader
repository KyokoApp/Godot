shader_type spatial;
render_mode diffuse_burley, specular_disabled;

varying vec3 world_position;

float tile_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Jalan selebar tiga petak: tiga kolom @ 2 m, dengan sambungan tiap 4 m.
	vec2 cell = vec2((world_position.x + 3.0) / 2.0, world_position.z / 4.0);
	vec2 local = fract(cell);
	float edge = min(min(local.x, 1.0 - local.x), min(local.y, 1.0 - local.y));
	float tile = smoothstep(0.012, 0.045, edge);
	float variation = tile_hash(floor(cell));
	vec3 dark_stone = vec3(0.075, 0.080, 0.105);
	vec3 pale_stone = vec3(0.155, 0.160, 0.195);
	vec3 seam = vec3(0.028, 0.032, 0.048);
	vec3 slab = mix(dark_stone, pale_stone, 0.30 + variation * 0.42);
	ALBEDO = mix(seam, slab, tile);
	ROUGHNESS = 0.96;
}
