shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

uniform float lean = 0.0;
uniform float heat = 0.0;
uniform float gust = 0.0;
uniform float flicker = 0.5;


float hash(vec2 point) {
	return fract(sin(dot(point, vec2(127.1, 311.7))) * 43758.5453);
}


float noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash(cell);
	float b = hash(cell + vec2(1.0, 0.0));
	float c = hash(cell + vec2(0.0, 1.0));
	float d = hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}


float tongue(vec2 uv, float center, float height, float width, float seed) {
	float h = (1.0 - uv.y) / height;
	if (h <= 0.0 || h >= 1.0) {
		return 0.0;
	}
	float flow = TIME * (2.5 + heat * 1.6 + gust * 0.8);
	float slow = noise(vec2(uv.x * 6.0 + seed, h * 4.0 - flow));
	float fast = noise(vec2(uv.x * 11.0 - seed, h * 8.0 - flow * 1.65));
	float centerline = center + sin(h * 6.2 - flow * 0.8 + seed) * 0.045 * h;
	centerline += (slow - 0.5) * 0.09 * h + lean * pow(h, 1.55) * 0.22;
	float envelope = width * pow(max(0.0, 1.0 - h), 0.62);
	envelope *= 0.84 + slow * 0.28 + sin(h * 12.0 - flow + seed) * 0.035;
	float ragged_edge = (fast - 0.5) * 0.045 * h;
	float edge = abs((uv.x - 0.5) - centerline) + ragged_edge;
	return 1.0 - smoothstep(envelope - 0.012, envelope + 0.012, edge);
}


void vertex() {
	float h = 1.0 - UV.y;
	VERTEX.x += lean * pow(h, 1.55) * 0.19;
	VERTEX.y *= 1.0 + heat * 0.19 + gust * 0.07;
	VERTEX.x *= 1.0 - heat * 0.055;
}


void fragment() {
	float h = 1.0 - UV.y;
	float main = tongue(UV, 0.0, 1.0, 0.43, 0.2);
	float left = tongue(UV, -0.16, 0.80 + sin(TIME * 2.1 + 1.2) * 0.045,
		0.22, 3.4) * 0.88;
	float right = tongue(UV, 0.16, 0.72 + sin(TIME * 1.8 + 3.1) * 0.055,
		0.20, 7.1) * 0.82;
	float coverage = max(main, max(left, right));
	float base_fade = smoothstep(0.015, 0.11, h);
	float tip_fade = 1.0 - smoothstep(0.89, 1.0, h);
	float opacity = coverage * base_fade * tip_fade;

	float centerline = 0.5 + lean * pow(h, 1.55) * 0.22;
	float width = max(0.035, 0.43 * pow(max(0.0, 1.0 - h), 0.62));
	float radial = clamp(abs(UV.x - centerline) / width, 0.0, 1.0);
	float inner_heat = 1.0 - smoothstep(0.12, 0.78, radial);
	float base_heat = 1.0 - smoothstep(0.18, 0.78, h);

	vec3 ember = vec3(0.20, 0.018, 0.001);
	vec3 orange = vec3(0.88, 0.10, 0.006);
	vec3 gold = vec3(1.0, 0.32, 0.018);
	vec3 yellow = vec3(1.0, 0.62, 0.12);
	vec3 hot_core = vec3(1.0, 0.82, 0.45);
	vec3 color = mix(ember, orange, 1.0 - smoothstep(0.22, 0.95, radial));
	color = mix(color, gold, inner_heat * (0.50 + base_heat * 0.18));
	color = mix(color, yellow, inner_heat * base_heat * 0.50);
	color = mix(color, hot_core, inner_heat * base_heat * 0.12);
	color = mix(color, orange, smoothstep(0.45, 0.98, h) * 0.72);
	float pulse = 0.90 + flicker * 0.10 + sin(TIME * 9.3 + UV.x * 18.0) * 0.02;
	ALBEDO = color * pulse;
	EMISSION = color * (0.08 + inner_heat * base_heat * 0.24);
	ALPHA = opacity * (0.84 + inner_heat * 0.10);
}
