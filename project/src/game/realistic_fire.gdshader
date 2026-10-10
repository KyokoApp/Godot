shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never, shadows_disabled;

uniform float lean = 0.0;
uniform float heat = 0.0;
uniform float gust = 0.0;
uniform float flicker = 0.5;
uniform float seed = 0.0;
uniform float core = 0.0;


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


void vertex() {
	float height = UV.y;
	float phase = TIME * (3.8 + heat * 1.3 + gust * 0.7) + seed;
	float sway = sin(phase + height * 4.1) * 0.025 * height;
	float cross_sway = cos(phase * 0.77 + height * 5.3) * 0.020 * height;
	VERTEX.x += sway + lean * pow(height, 1.45) * 0.28;
	VERTEX.z += cross_sway;
	VERTEX.xz *= 1.0 + sin(TIME * 5.2 + seed + height * 2.0) * 0.035 * height;
	VERTEX.y *= 1.0 + sin(TIME * 6.4 + seed) * 0.035 + heat * 0.10 + gust * 0.035;
}


void fragment() {
	float height = UV.y;
	float flow = TIME * (2.3 + heat * 1.1 + gust * 0.8);
	float turbulence = noise(vec2(UV.x * 4.0 + seed, height * 5.0 - flow));
	float fine_turbulence = noise(vec2(UV.x * 9.0 - seed, height * 9.0 - flow * 1.45));
	float flicker_value = 0.88 + flicker * 0.12 + turbulence * 0.08;
	float edge_glow = 0.74 + 0.26 * abs(NORMAL.z);

	vec3 ember = vec3(0.30, 0.025, 0.003);
	vec3 orange = vec3(1.0, 0.16, 0.012);
	vec3 gold = vec3(1.0, 0.52, 0.08);
	vec3 hot_core = vec3(1.0, 0.83, 0.48);
	float base_heat = 1.0 - smoothstep(0.05, 0.54, height);
	float upper = smoothstep(0.16, 0.72, height);
	vec3 color = mix(ember, orange, smoothstep(0.0, 0.23, height));
	color = mix(color, gold, upper * (0.40 + core * 0.28));
	color = mix(color, hot_core, core * base_heat * 0.54);
	color = mix(color, orange, smoothstep(0.62, 0.98, height) * 0.34);
	color *= flicker_value * (0.94 + fine_turbulence * 0.10);

	float base_fade = smoothstep(0.0, 0.075, height);
	float tip_fade = 1.0 - smoothstep(0.82, 1.0, height);
	float layer_alpha = mix(0.70, 0.94, core);
	ALBEDO = color * edge_glow;
	EMISSION = color * (0.42 + core * 0.22);
	ALPHA = base_fade * tip_fade * layer_alpha * (0.93 + turbulence * 0.07);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
