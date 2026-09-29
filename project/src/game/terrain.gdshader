shader_type spatial;
render_mode diffuse_burley, specular_disabled;
// Per-fragment dirt boundary, not triangle-interpolated road vertex colors.
uniform vec4 dirt_color : source_color = vec4(0.662745, 0.470588, 0.282353, 1.0);
uniform sampler2D meadow_cover : filter_linear_mipmap, repeat_enable;
uniform bool grass_cover_enabled = true;
varying float green_land;
varying vec3 world_position;
varying vec3 ground_color;

vec3 srgb_to_linear(vec3 color) {
	return mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)),
		step(vec3(0.04045), color));
}
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ground_color = srgb_to_linear(COLOR.rgb);
	green_land = smoothstep(0.04, 0.12, ground_color.g - max(ground_color.r, ground_color.b));
	green_land *= smoothstep(0.88, 0.95, NORMAL.y);
}
void fragment() {
	float z = world_position.z;
	float center = 65.0 * sin(z / 95.0) + 22.0 * sin(z / 43.0);
	float slope = (65.0 / 95.0) * cos(z / 95.0) + (22.0 / 43.0) * cos(z / 43.0);
	float distance = abs(world_position.x - center) / sqrt(1.0 + slope * slope);
	float road = 1.0 - smoothstep(9.0, 11.0, distance);
	road *= 1.0 - smoothstep(300.0, 335.0, abs(z));
	vec3 land = ground_color;
	if (grass_cover_enabled) {
		float pattern = texture(meadow_cover, world_position.xz * 0.16).r;
		land *= mix(1.0, mix(0.82, 1.02, pattern), green_land);
	}
	ALBEDO = mix(land, dirt_color.rgb, road);
	ROUGHNESS = 1.0;
}
