shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// Kobaran biru kecil selalu menghadap kamera, dengan lidah api yang berubah
// bentuk dan ekor tipis saat bergerak.
uniform vec3 outer_blue = vec3(0.015, 0.07, 0.58);
uniform vec3 inner_blue = vec3(0.025, 0.32, 1.0);
uniform vec3 heat_blue = vec3(0.04, 0.68, 1.0);
uniform vec3 core_blue = vec3(0.72, 0.94, 1.2);
uniform vec3 outline_blue = vec3(0.01, 0.035, 0.22);
uniform vec3 trail = vec3(0.0);
uniform float glow = 0.0;

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

float tongue(vec2 point, float center, float height, float seed, float width) {
	float h = point.y / height;
	if (h <= 0.0 || h >= 1.0) {
		return 0.0;
	}
	float grain = noise(vec2(point.x * 9.0 + seed, h * 5.0 - TIME * 3.2));
	float curl = sin(h * 7.0 - TIME * 4.0 + seed) * 0.055 * h;
	float taper = pow(sin(h * 3.14159), 0.7) * pow(1.0 - h, 0.4);
	float radius = width * taper * (0.72 + grain * 0.65);
	float body = 1.0 - smoothstep(radius - 0.012, radius + 0.012,
		abs(point.x - center - curl));
	float tear = noise(vec2(point.x * 17.0 + seed, h * 8.0 - TIME * 5.0));
	return body * (1.0 - smoothstep(0.60, 0.82, tear * h));
}

void vertex() {
	mat4 facing = mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
	float tip = pow(1.0 - UV.y, 1.8);
	VERTEX.x += dot(trail, INV_VIEW_MATRIX[0].xyz) * tip;
	VERTEX.y += dot(trail, INV_VIEW_MATRIX[1].xyz) * tip;
}

void fragment() {
	vec2 point = vec2(UV.x - 0.5, (1.0 - UV.y) * 1.12 - 0.035);
	float main = tongue(point, 0.0, 0.94 + sin(TIME * 3.7) * 0.045,
		0.0, 0.27);
	float left = tongue(point, -0.15, 0.62 + sin(TIME * 4.3) * 0.07,
		3.7, 0.13);
	float right = tongue(point, 0.15, 0.73 + sin(TIME * 3.1 + 2.0) * 0.07,
		8.2, 0.12);
	float flame = max(main, max(left, right));
	float heat = tongue(vec2(point.x, point.y + 0.04), 0.0, 0.58, 1.2, 0.17);
	float core = tongue(vec2(point.x, point.y + 0.02), 0.0, 0.35, 2.1, 0.09);
	vec3 color = mix(outer_blue, inner_blue, main);
	color = mix(color, heat_blue, heat * 0.90);
	color = mix(color, core_blue, core);
	float edge_width = clamp(fwidth(flame) * 0.55, 0.001, 0.55);
	float outline = (1.0 - smoothstep(0.12, 0.12 + edge_width, flame));
	color = mix(color, outline_blue, outline * 0.85);
	ALBEDO = color * (1.05 + glow * 0.25);
	ALPHA = flame * 0.96;
}
