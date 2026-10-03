shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
// Laut di kejauhan: gradasi biru malam -> biru pucat dekat pantai, jalur kilau
// BULAN, dan riak halus. Dipakai satu bidang besar di luar padang (bukan bagian
// gameplay), jadi biayanya hanya satu draw call + beberapa sin().

uniform vec4 deep_color : source_color = vec4(0.020, 0.055, 0.105, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.075, 0.150, 0.215, 1.0);
uniform vec4 sun_color : source_color = vec4(0.62, 0.74, 0.98, 1.0);
// Default-nya dibalik dari arah bulan (15 derajat, barat daya); dikirim juga dari
// main.gd, jadi di layar dan di gambar tes nilainya sama.
uniform vec3 sun_direction = vec3(-0.91, 0.26, -0.31);
uniform float ripple = 0.35;
uniform float horizon_fade = 140.0;

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
	// Kilau bulan: jalur terang di arah bulan, memanjang di air sampai ke pemain.
	vec3 to_sun = normalize(sun_direction);
	float glint = pow(max(dot(normalize(world_position - CAMERA_POSITION_WORLD), to_sun),
		0.0), 24.0);
	water += sun_color.rgb * glint * 0.85;
	// Garis horizon dibuat lebih terang supaya laut "menyatu" dengan langit
	// seperti di ilustrasi.
	water = mix(water, sun_color.rgb * 0.85 + shallow_color.rgb * 0.15,
		(1.0 - distance_fade) * 0.0 + pow(1.0 - distance_fade, 3.0) * 0.35);
	ALBEDO = water;
	ROUGHNESS = 0.16;
	METALLIC = 0.0;
}
