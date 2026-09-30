shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform float fog_amount : hint_range(0.0, 1.0) = 0.0;
varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Seamless broad drifting billows, not sine stripes or a white ceiling.
	vec2 p = vec2(world_position.x + world_position.z, world_position.y) * 0.085;
	vec2 drift = vec2(TIME * 0.035, -TIME * 0.022);
	float broad = noise(p + drift);
	float folds = noise(p * 2.1 - drift + broad * 1.7);
	float shade = mix(0.32, 0.65, broad * 0.65 + folds * 0.35);
	ALBEDO = vec3(shade, shade + 0.012, shade + 0.025);
	// Dense outside the ring at eye level, softly dissolving into the original sky.
	float top = 1.0 - smoothstep(0.30 + broad * 0.08, 1.0, UV.y);
	ALPHA = fog_amount * 0.98 * top;
}
