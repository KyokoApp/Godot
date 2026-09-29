shader_type spatial;
render_mode diffuse_burley, specular_disabled;
// Per-fragment dirt boundary, not triangle-interpolated road vertex colors.
uniform vec4 dirt_color : source_color = vec4(0.662745, 0.470588, 0.282353, 1.0);
varying vec3 world_position;

vec3 srgb_to_linear(vec3 color) {
	return mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)),
		step(vec3(0.04045), color));
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float z = world_position.z;
	float center = 65.0 * sin(z / 95.0) + 22.0 * sin(z / 43.0);
	float slope = (65.0 / 95.0) * cos(z / 95.0) + (22.0 / 43.0) * cos(z / 43.0);
	float distance = abs(world_position.x - center) / sqrt(1.0 + slope * slope);
	float road = 1.0 - smoothstep(9.0, 11.0, distance);
	road *= 1.0 - smoothstep(300.0, 335.0, abs(z));
	ALBEDO = mix(srgb_to_linear(COLOR.rgb), dirt_color.rgb, road);
	ROUGHNESS = 1.0;
}
