shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
// Laut di kejauhan: gradasi biru tosca -> hijau pucat dekat pantai, kilau
// matahari senja, dan riak halus. Dipakai satu bidang besar di luar padang (bukan
// bagian gameplay), jadi biayanya hanya satu draw call + beberapa sin().

uniform vec4 deep_color : source_color = vec4(0.125, 0.415, 0.541, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.361, 0.780, 0.741, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.86, 0.70, 1.0);
uniform vec3 sun_direction = vec3(-0.94, 0.10, -0.32);
uniform float ripple = 0.35;
uniform float horizon_fade = 380.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Riak: dua gelombang berjalan, makin kuat ke arah kamera.
	float wave_a = sin(world_position.x * 0.22 + TIME * 0.5);
	float wave_b = sin(world_position.z * 0.17 - TIME * 0.37);
	float waves = (wave_a + wave_b) * 0.5 * ripple;
	float distance_fade = 1.0 - smoothstep(horizon_fade * 0.35, horizon_fade,
		length(world_position.xz - CAMERA_POSITION_WORLD.xz));
	vec3 water = mix(deep_color.rgb, shallow_color.rgb, waves * 0.5 + 0.5);
	// Kilau matahari: titik terang di arah matahari terbenam, memanjang di air.
	vec3 to_sun = normalize(sun_direction);
	float glint = pow(max(dot(normalize(world_position - CAMERA_POSITION_WORLD), to_sun),
		0.0), 24.0);
	water += sun_color.rgb * glint * 0.55;
	// Garis horizon dibuat lebih terang supaya laut "menyatu" dengan langit
	// seperti di ilustrasi.
	water = mix(water, sun_color.rgb * 0.85 + shallow_color.rgb * 0.15,
		(1.0 - distance_fade) * 0.0 + pow(1.0 - distance_fade, 3.0) * 0.35);
	ALBEDO = water;
	ROUGHNESS = 0.16;
	METALLIC = 0.0;
}
