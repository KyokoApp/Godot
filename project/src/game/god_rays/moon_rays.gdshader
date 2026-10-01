shader_type spatial;
// Original depth-mask adaptation of a radial-scattering method.
// Attribution and license terms: project/licenses/LICENSES.txt.
// No SubViewport / duplicate world render. Reverse-Z, Godot 4.3+ Mobile / Forward+.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, depth_test_disabled,
	shadows_disabled, fog_disabled;
uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec2 source_uv = vec2(0.5);
uniform float aspect = 1.7778;
uniform float strength = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float rays = 0.0;
	// Limit the effect to unobstructed sky; never wash out characters or terrain.
	if (texture(depth_tex, SCREEN_UV).r < 0.00001 && strength > 0.0) {
		vec2 step_uv = (source_uv - SCREEN_UV) * (0.85 / 16.0);
		vec2 uv = SCREEN_UV;
		float decay = 1.0;
		for (int i = 0; i < 16; i++) {
			uv += step_uv;
			float sky = step(texture(depth_tex, uv).r, 0.00001);
			float disk = 1.0 - smoothstep(0.008, 0.065,
				length((uv - source_uv) * vec2(aspect, 1.0)));
			rays += sky * disk * decay;
			decay *= 0.96;
		}
	}
	ALBEDO = vec3(0.55, 0.69, 1.0);
	ALPHA = rays * strength / 16.0;
}
