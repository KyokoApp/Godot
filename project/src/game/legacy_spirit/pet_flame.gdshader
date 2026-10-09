shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Original pet-only flame: three tapered tongues with rising, eroding contours.
// Camera-facing card keeps the small silhouette readable without an opaque orb.
uniform vec3 trail = vec3(0.0);
uniform float pulse = 0.0;
uniform float outline_pixels : hint_range(0.0, 1.0) = 0.55;
uniform vec3 spell_tint : source_color = vec3(1.0, 0.45, 0.14);
uniform float tint_mix : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float tongue(vec2 p, float center, float height, float seed, float width) {
	float h = p.y / height;
	if (h <= 0.0 || h >= 1.0) { return 0.0; }
	float n = noise(vec2(p.x * 9.0 + seed, h * 5.0 - TIME * 3.2));
	float curl = sin(h * 7.0 - TIME * 4.0 + seed) * 0.055 * h;
	float taper = pow(sin(h * 3.14159), 0.7) * pow(1.0 - h, 0.4);
	float radius = width * taper * (0.72 + n * 0.65);
	float distance = abs(p.x - center - curl);
	float body = 1.0 - smoothstep(radius - 0.012, radius + 0.012, distance);
	float tear = noise(vec2(p.x * 17.0 + seed, h * 8.0 - TIME * 5.0));
	return body * (1.0 - smoothstep(0.60, 0.82, tear * h));
}
void vertex() {
	mat4 facing = mat4(
		vec4(INV_VIEW_MATRIX[0].xyz * length(MODEL_MATRIX[0].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[1].xyz * length(MODEL_MATRIX[1].xyz), 0.0),
		vec4(INV_VIEW_MATRIX[2].xyz * length(MODEL_MATRIX[2].xyz), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = VIEW_MATRIX * facing;
	float top = pow(1.0 - UV.y, 1.8);
	// Project the world-space movement tail into the facing card's local plane.
	VERTEX.x += dot(trail, INV_VIEW_MATRIX[0].xyz) * top;
	VERTEX.y += dot(trail, INV_VIEW_MATRIX[1].xyz) * top;
}
void fragment() {
	vec2 p = vec2(UV.x - 0.5, (1.0 - UV.y) * 1.12 - 0.035);
	float main = tongue(p, 0.0, 0.94 + sin(TIME * 3.7) * 0.045, 0.0, 0.27);
	float left = tongue(p, -0.15, 0.62 + sin(TIME * 4.3) * 0.07, 3.7, 0.13);
	float right = tongue(p, 0.15, 0.73 + sin(TIME * 3.1 + 2.0) * 0.07, 8.2, 0.12);
	float flame = max(main, max(left, right));
	float heat = tongue(vec2(p.x, p.y + 0.04), 0.0, 0.58, 1.2, 0.17);
	float core = tongue(vec2(p.x, p.y + 0.02), 0.0, 0.35, 2.1, 0.09);
	vec3 color = mix(vec3(0.38, 0.13, 0.82), vec3(0.70, 0.45, 1.0), main);
	color = mix(color, vec3(0.34, 0.72, 1.0), heat * 0.90);
	color = mix(color, vec3(0.85, 0.96, 1.0), core);
	// Sihir tint: blending smooth antar skill, tetap pakai lidah api yang sama.
	color = mix(color, spell_tint * (0.85 + core * 0.35), tint_mix * 0.72);
	color = mix(color, vec3(1.0, 1.0, 0.95) * 0.9 + spell_tint * 0.15, core * tint_mix * 0.55);
	// Subpixel inner contour: same silhouette/motion, no extra pass or expanded halo.
	float width = clamp(fwidth(flame) * outline_pixels, 0.001, 0.55);
	float outline = (1.0 - smoothstep(0.12, 0.12 + width, flame));
	outline *= step(0.001, outline_pixels);
	color = mix(color, vec3(0.14, 0.08, 0.27), outline * 0.85);
	ALBEDO = color * (1.05 + pulse * 0.25);
	ALPHA = flame * 0.94;
}
