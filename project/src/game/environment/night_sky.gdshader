shader_type sky;
// Original static night sky: sparse fixed stars, a small moon, no full-screen filter.
uniform vec3 moon_direction = vec3(-0.31, 0.24, -0.92);
uniform float moon_radius = 0.0055;
uniform bool stars_enabled = true;
// Pita senja: sisi barat (-x) tempat matahari baru terbenam, seperti di ilustrasi
// layar muat. Hanya di dekat horizon; zenith tetap biru malam supaya bintang dan
// bulan tidak tenggelam.
uniform bool dusk_enabled = true;
uniform vec3 dusk_direction = vec3(-0.97, 0.0, -0.24);
uniform vec4 dusk_color : source_color = vec4(1.0, 0.62, 0.36, 1.0);
uniform bool moon_enabled = true;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
void sky() {
	vec3 direction = normalize(EYEDIR);
	float elevation = max(direction.y, 0.0);
	vec3 horizon = vec3(0.038, 0.048, 0.090);
	vec3 zenith = vec3(0.006, 0.010, 0.035);
	vec3 color = mix(horizon, zenith, pow(elevation, 0.45));
	color += vec3(0.009, 0.005, 0.014) * exp(-pow(elevation * 9.0, 2.0));
	color = mix(vec3(0.008, 0.012, 0.022), color, smoothstep(-0.12, 0.02, direction.y));
	if (dusk_enabled) {
		float towards = max(dot(normalize(vec3(direction.x, 0.0, direction.z)),
			normalize(dusk_direction)), 0.0);
		float band = exp(-pow(max(direction.y, 0.0) * 5.5, 1.4));
		float glow = pow(towards, 3.0) * band;
		color = mix(color, dusk_color.rgb * 0.85, glow * 0.75);
		color += dusk_color.rgb * glow * 0.28;
	}
	if (stars_enabled) {
		vec2 uv = vec2(atan(direction.x, direction.z) / 6.283185 + 0.5,
			acos(clamp(direction.y, -1.0, 1.0)) / 3.141593);
		vec2 grid = uv * vec2(90.0, 45.0);
		vec2 cell = floor(grid);
		vec2 center = vec2(0.2) + vec2(hash(cell + 17.3), hash(cell + 41.9)) * 0.6;
		float radius = mix(0.018, 0.045, hash(cell + 9.1));
		float aa = max(length(fwidth(grid)) * 0.45, 0.001);
		float star = 1.0 - smoothstep(max(0.0, radius - aa), radius + aa,
			length(fract(grid) - center));
		star *= min(1.0, radius / aa) * step(0.965, hash(cell));
		star *= smoothstep(0.06, 0.25, direction.y) * (1.0 - smoothstep(0.90, 1.0, direction.y));
		vec3 tint = mix(vec3(0.66, 0.79, 1.0), vec3(1.0, 0.90, 0.76), hash(cell + 7.0));
		color += tint * star * 1.8;
	}
	if (moon_enabled) {
		vec3 moon = normalize(moon_direction);
		float distance = length(direction - moon);
		float aa = max(length(fwidth(direction)) * 0.55, 0.0001);
		float disk = 1.0 - smoothstep(moon_radius - aa, moon_radius + aa, distance);
		vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), moon));
		vec3 up = cross(moon, right);
		vec2 face = vec2(dot(direction - moon, right), dot(direction - moon, up)) / moon_radius;
		float crater = exp(-length(face - vec2(-0.3, 0.2)) * 9.0);
		crater += exp(-length(face - vec2(0.25, -0.3)) * 12.0) * 0.7;
		float halo = exp(-distance * distance / 0.00045) * 0.025;
		color += vec3(0.50, 0.62, 1.0) * halo;
		color = mix(color, vec3(1.30, 1.40, 1.60) * (1.0 - crater * 0.22), disk);
	}
	COLOR = color;
}
