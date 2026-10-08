shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 mist_color : source_color = vec4(0.17, 0.20, 0.31, 1.0);
uniform float haze_start = 90.0;
uniform float haze_end = 390.0;
uniform float haze_strength = 0.94;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float distance_to_camera = distance(CAMERA_POSITION_WORLD, world_position);
	float haze = smoothstep(haze_start, haze_end, distance_to_camera) * haze_strength;
	ALBEDO = mix(COLOR.rgb, mist_color.rgb, haze);
}
