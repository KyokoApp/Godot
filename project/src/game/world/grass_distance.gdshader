shader_type spatial;
render_mode cull_disabled, world_vertex_coords, diffuse_burley, specular_disabled;
uniform sampler2D blade_mask : filter_linear_mipmap, repeat_disable;
uniform vec3 player_position;
// Sama dengan grass.gdshader dan field.gd: satu warna gelap dengan tanah.
uniform vec3 bottom_color : source_color = vec3(0.176, 0.310, 0.153);
uniform vec3 top_color : source_color = vec3(0.247, 0.420, 0.204);
void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0, 0, 0, 1)).xyz;
	float distance = length(root.xz - player_position.xz);
	// Muncul tepat setelah helai rapat padam (24 m), padam perlahan di 130 m.
	float visibility = smoothstep(19.0, 27.0, distance);
	visibility *= 1.0 - smoothstep(100.0, 130.0, distance);
	VERTEX = mix(root, VERTEX, visibility);
	VERTEX.x += sin(TIME * 1.5 + root.z * 0.4) * 0.055 * (1.0 - UV.y) * visibility;
}
void fragment() {
	ALBEDO = mix(bottom_color, top_color, 1.0 - UV.y);
	ALPHA = texture(blade_mask, UV).r;
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	ROUGHNESS = 1.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(0, 1, 0, 0)).xyz);
}
