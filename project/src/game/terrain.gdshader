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
float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
vec3 arena_ground(vec2 p) {
	vec2 cells = p * 0.65;
	vec2 base = floor(cells);
	vec2 local = fract(cells);
	float first = 9.0;
	float second = 9.0;
	float seed = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 site = offset + vec2(grain(base + offset), grain(base + offset + 19.3));
			float d = length(site - local);
			if (d < first) { second = first; first = d; seed = grain(base + offset); }
			else { second = min(second, d); }
		}
	}
	float seams = 1.0 - smoothstep(0.018, 0.065, second - first);
	vec3 stone = mix(vec3(0.24, 0.21, 0.17), vec3(0.42, 0.39, 0.32), seed);
	stone *= 0.94 + 0.06 * grain(floor(p * 12.0));
	stone = mix(stone, vec3(0.12, 0.10, 0.08), seams * 0.65);
	float r = length(p);
	float angle = atan(p.y, p.x);
	float crack = abs(sin(angle * 5.5 + sin(r * 0.6) * 0.10 + sin(r * 1.8) * 0.04));
	float width = 0.22 / max(r, 0.7);
	float fracture = 1.0 - smoothstep(width, width * 2.0 + 0.005, crack);
	fracture *= 1.0 - smoothstep(30.0, 42.0, r);
	return mix(stone, vec3(0.065, 0.055, 0.045), fracture * 0.9);
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
	vec2 arena_p = world_position.xz - vec2(-145.0, 140.0);
	float angle = atan(arena_p.y, arena_p.x);
	float boundary = 42.0 + 1.4 * sin(angle * 5.0) + 0.7 * cos(angle * 9.0);
	float arena_mask = 1.0 - smoothstep(-0.5, 1.2, length(arena_p) - boundary);
	if (arena_mask > 0.0) {
		ALBEDO = mix(ALBEDO, arena_ground(arena_p), arena_mask);
	}
	ROUGHNESS = 1.0;
}
