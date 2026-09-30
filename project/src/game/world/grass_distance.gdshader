shader_type spatial;
render_mode cull_disabled, world_vertex_coords, diffuse_burley, specular_disabled;
uniform sampler2D blade_mask : filter_linear_mipmap, repeat_disable;
uniform vec3 player_position;
uniform vec3 bottom_color : source_color = vec3(0.29, 0.53, 0.19);
uniform vec3 top_color : source_color = vec3(0.38, 0.65, 0.24);
void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0, 0, 0, 1)).xyz;
	float distance = length(root.xz - player_position.xz);
	float visibility = smoothstep(14.0, 23.0, distance);
	visibility *= 1.0 - smoothstep(65.0, 90.0, distance);
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
