shader_type spatial;
render_mode cull_back;

uniform float flight_blend = 0.0;
uniform float motion_strength = 0.0;
varying vec3 blob_position;


void vertex() {
	vec3 p = VERTEX;
	float time = TIME;
	float broad_wave = sin(p.x * 13.0 + p.y * 8.0 + p.z * 5.0 + time * 0.82)
		* cos(p.z * 11.0 - p.y * 7.0 - time * 0.61);
	float soft_wave = cos(p.x * 8.0 - p.z * 12.0 + time * 0.57)
		* sin(p.y * 10.0 + p.x * 6.0 - time * 0.73);
	float ripple = broad_wave * 0.014 + soft_wave * 0.006;
	VERTEX += NORMAL * ripple * (0.82 + flight_blend * 0.28 + motion_strength * 0.08);
	blob_position = p;
}


void fragment() {
	float broad = sin(blob_position.x * 12.0 + blob_position.y * 8.0 + TIME * 0.74)
		* cos(blob_position.z * 11.0 - blob_position.y * 7.0 - TIME * 0.58);
	float fine = cos(blob_position.z * 17.0 + blob_position.x * 5.0 - TIME * 0.52)
		* sin(blob_position.y * 13.0 - blob_position.x * 8.0 + TIME * 0.63);
	float waves = clamp(0.5 + broad * 0.32 + fine * 0.12, 0.0, 1.0);
	float crest = smoothstep(0.56, 0.94, waves);
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 2.15);

	vec3 deep_blue = vec3(0.012, 0.075, 0.30);
	vec3 ocean_blue = vec3(0.018, 0.28, 0.72);
	vec3 wave_blue = vec3(0.075, 0.53, 0.96);
	vec3 soft_cyan = vec3(0.22, 0.76, 1.0);
	vec3 color = mix(deep_blue, ocean_blue, smoothstep(0.03, 0.82, waves));
	color = mix(color, wave_blue, crest * 0.72);
	color = mix(color, soft_cyan, rim * (0.24 + flight_blend * 0.22));

	ALBEDO = color;
	METALLIC = 0.16;
	ROUGHNESS = 0.25 + (1.0 - waves) * 0.08;
	SPECULAR = 0.78;
	EMISSION = color * (0.035 + flight_blend * 0.23)
		+ vec3(0.015, 0.09, 0.25) * rim * flight_blend * 0.58;
}
