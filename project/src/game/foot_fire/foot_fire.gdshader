shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// Original 3D shoe-shaped fire, inspired by the pet's rising toon tongues.
// Mesh volume, no billboard facing and no extra light/shadow/particle systems.
uniform float age = 0.0;
uniform float seed = 0.0;
uniform vec3 cool : source_color = vec3(0.45, 0.15, 0.9);
uniform vec3 middle : source_color = vec3(0.3, 0.65, 1.0);
uniform vec3 hot : source_color = vec3(0.86, 0.97, 1.0);
varying float height;
varying float flame;

void vertex() {
	height = COLOR.r;
	flame = COLOR.g;
	float phase = TIME * 7.0 + seed + COLOR.b * 9.0;
	float tip = height * height * flame;
	VERTEX.x += sin(phase + height * 5.0) * 0.022 * tip;
	VERTEX.z += cos(phase * 0.83 + height * 4.0) * 0.015 * tip;
	VERTEX.y *= (1.0 - smoothstep(0.5, 1.0, age)) * (1.0 + sin(phase) * 0.12 * tip);
}

void fragment() {
	float ripple = sin(UV.x * 18.85 + UV.y * 12.0 - TIME * 9.0 + seed) * 0.5 + 0.5;
	float heat = clamp((1.0 - height) * 0.9 + ripple * 0.17, 0.0, 1.0);
	vec3 color = mix(cool, middle, smoothstep(0.05, 0.65, heat));
	color = mix(color, hot, smoothstep(0.62, 1.0, heat));
	float fade = 1.0 - smoothstep(0.40, 1.0, age);
	ALBEDO = color * 1.1;
	ALPHA = fade * mix(0.48, 0.80 - height * ripple * 0.25, flame);
}
