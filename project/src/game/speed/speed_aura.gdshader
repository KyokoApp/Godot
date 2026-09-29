shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.25, 0.6, 1.0);
uniform float strength = 0.0;
uniform bool shell = false;
void fragment() {
	float soft;
	if (shell) {
		float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.3);
		float flow = 0.72 + 0.28 * sin(UV.y * 14.0 - TIME * 4.0 + sin(UV.x * 12.0));
		soft = rim * flow * smoothstep(0.0, 0.2, UV.y) * smoothstep(0.0, 0.2, 1.0 - UV.y);
		soft *= 0.25;
	} else {
		float across = abs(UV.y * 2.0 - 1.0);
		float halo = exp(-across * across * 7.0);
		float core = exp(-across * across * 75.0);
		soft = (halo * 0.4 + core * 0.6) * smoothstep(0.0, 0.12, UV.x);
		soft *= pow(1.0 - UV.x, 1.5);
	}
	ALBEDO = mix(tint, vec3(1.0), 0.14) * 4.0;
	ALPHA = soft * strength;
}
