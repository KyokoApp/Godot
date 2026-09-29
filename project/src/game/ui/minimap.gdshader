shader_type canvas_item;
uniform vec2 center_uv = vec2(0.5);
uniform float span = 0.25;
void fragment() {
	vec2 uv = center_uv + (UV - vec2(0.5)) * span;
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	vec3 terrain = mix(vec3(0.337, 0.549, 0.612), texture(TEXTURE, uv).rgb, inside);
	float radius = length(UV - vec2(0.5));
	float alpha = 1.0 - smoothstep(0.492, 0.5, radius);
	COLOR = vec4(terrain * (1.0 - smoothstep(0.35, 0.5, radius) * 0.18), alpha);
}
