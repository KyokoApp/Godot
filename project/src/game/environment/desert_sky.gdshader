shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.24, 0.39, 0.48);
uniform vec3 middle_color : source_color = vec3(0.50, 0.60, 0.63);
uniform vec3 horizon_color : source_color = vec3(0.79, 0.64, 0.46);
uniform vec3 haze_color : source_color = vec3(0.88, 0.72, 0.53);


void sky() {
	vec3 direction = normalize(EYEDIR);
	float elevation = max(direction.y, 0.0);
	vec3 color = mix(horizon_color, middle_color, smoothstep(0.015, 0.38, elevation));
	color = mix(color, zenith_color, smoothstep(0.22, 0.88, elevation));
	float low_haze = exp(-elevation * 12.0);
	color = mix(color, haze_color, low_haze * 0.42);

	if (LIGHT0_ENABLED) {
		vec3 to_sun = normalize(LIGHT0_DIRECTION);
		float angle = acos(clamp(dot(direction, to_sun), -1.0, 1.0));
		float disc = 1.0 - smoothstep(0.006, 0.010, angle);
		float aureole = exp(-angle * angle * 92.0) * 0.12;
		vec3 sun_color = vec3(1.0, 0.76, 0.50) * LIGHT0_ENERGY;
		color += sun_color * (disc * 1.25 + aureole);
	}
	COLOR = color;
}
