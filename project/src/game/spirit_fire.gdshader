shader_type spatial;
render_mode diffuse_toon, specular_disabled;

uniform vec3 blue : source_color = vec3(0.25, 0.64, 0.95);
uniform vec3 purple : source_color = vec3(0.57, 0.28, 0.90);
uniform float strength = 0.12;

void vertex() {
	float tip = max(VERTEX.y, 0.0);
	VERTEX.x += sin(TIME * 3.5 + VERTEX.y * 6.0) * tip * strength;
	VERTEX.z += cos(TIME * 2.8 + VERTEX.y * 5.0) * tip * strength;
	VERTEX.y += tip * tip * (0.35 + sin(TIME * 4.0 + VERTEX.x * 8.0) * 0.10);
}

void fragment() {
	float swirl = sin(UV.x * 25.1327 + UV.y * 13.0 - TIME * 3.0) * 0.5 + 0.5;
	float blend = smoothstep(0.05, 0.95, UV.y + swirl * 0.22);
	ALBEDO = mix(purple, blue, blend);
	ALBEDO = mix(ALBEDO, vec3(0.68, 0.88, 1.0), pow(swirl, 6.0) * 0.30);
	EMISSION = ALBEDO * 0.20;
	ROUGHNESS = 1.0;
}
