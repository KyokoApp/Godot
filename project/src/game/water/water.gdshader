// Adapted from Marcel Bankmann's GodotSSRWater (MIT, see licenses).
// Projection/depth, two-wave blend, refraction, screen-edge fade and SSR retained.
// Godot 4.5 Mobile reverse-Z; bounded optional SSR, proper normal spaces and miss fallback.
shader_type spatial;
render_mode unshaded, depth_draw_always, specular_disabled;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_nearest;
uniform sampler2D wave_a : repeat_enable, filter_linear_mipmap;
uniform sampler2D wave_b : repeat_enable, filter_linear_mipmap;
uniform sampler2D surface_normals_a : repeat_enable, filter_linear_mipmap;
uniform sampler2D surface_normals_b : repeat_enable, filter_linear_mipmap;
uniform float animation_speed = 1.0;
uniform bool ssr_enabled = false;
uniform bool ocean = false;
uniform vec3 moon_direction = vec3(-0.31, 0.24, -0.92);
uniform vec3 color_shallow : source_color = vec3(0.12, 0.32, 0.34);
uniform vec3 color_deep : source_color = vec3(0.035, 0.14, 0.22);
varying vec2 vertex_uv;
varying vec3 world_position;

float get_wave_height(vec2 uv_a, vec2 uv_b) {
	return (texture(wave_a, uv_a).y + texture(wave_b, uv_b).y) * 0.5;
}

vec3 get_mixed_normals(vec3 color1, vec3 color2) {
	vec3 n1 = color1 * 2.0 - 1.0;
	vec3 n2 = color2 * 2.0 - 1.0;
	return normalize(vec3(n1.xy + n2.xy, n1.z * n2.z));
}

void vertex() {
	vertex_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	// Tiny displacement; continuous world UVs across tiles and at the ocean outlet.
	VERTEX.y += (get_wave_height(vertex_uv / 15.0 + vec2(-0.02, -0.04) * (TIME * animation_speed),
		vertex_uv / 19.0 + vec2(0.015, -0.025) * (TIME * animation_speed)) - 0.5) * 0.07;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

bool is_within_screen_boundaries(vec2 point) {
	return point.x > 0.0 && point.x < 1.0 && point.y > 0.0 && point.y < 1.0;
}

vec2 get_uv_from_view_position(vec3 point, mat4 proj_m) {
	vec4 clip = proj_m * vec4(point, 1.0);
	return (clip.xy / clip.w) * 0.5 + 0.5;
}

vec3 get_view_position_from_uv(vec2 uv, float depth, mat4 inv_proj_m) {
	vec4 view_position = inv_proj_m * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return view_position.xyz / view_position.w;
}

float get_screen_border_alpha(vec2 screen_position) {
	vec2 shifted = 4.0 * screen_position * (1.0 - screen_position);
	return smoothstep(0.0, 0.32, shifted.x * shifted.y);
}

vec4 get_ssr_color(vec3 surface, vec3 normal, vec3 view, mat4 proj, mat4 inv_proj) {
	vec3 current = surface + normal * 0.12;
	vec3 direction = normalize(reflect(-view, normal));
	// Fixed ceiling: twelve probes, eighteen metres. Disabled means NO ray march.
	for (int i = 0; i < 12; i++) {
		current += direction * 1.5;
		if (current.z >= -0.05) { break; }
		vec2 uv = get_uv_from_view_position(current, proj);
		if (!is_within_screen_boundaries(uv)) { break; }
		float raw = texture(DEPTH_TEXTURE, uv).r;
		if (raw < 0.00001) { continue; } // reverse-Z sky: never a reflection hit
		vec3 probe = get_view_position_from_uv(uv, raw, inv_proj);
		float diff = probe.z - current.z;
		if (diff >= 0.0 && diff < 0.45 + float(i) * 0.03) {
			return vec4(texture(SCREEN_TEXTURE, uv).rgb, get_screen_border_alpha(uv));
		}
	}
	return vec4(-1.0, -1.0, -1.0, 0.0);
}

vec2 get_refracted_uv(vec2 uv, float raw, vec3 view, vec3 normal,
		mat4 proj, mat4 inv_proj) {
	vec3 original = get_view_position_from_uv(uv, raw, inv_proj);
	vec3 refracted = original + refract(-view, normal, 1.0 / 1.333) * 0.10;
	return clamp(get_uv_from_view_position(refracted, proj), vec2(0.001), vec2(0.999));
}

void fragment() {
	// Texture XY is the horizontal tangent plane, not a view-space normal.
	vec3 blended = get_mixed_normals(
		texture(surface_normals_a, vertex_uv * 0.09 + (TIME * animation_speed) * vec2(-0.012, -0.025)).rgb,
		texture(surface_normals_b, vertex_uv * 0.12 + (TIME * animation_speed) * vec2(0.017, -0.018)).rgb);
	vec3 world_normal = normalize(vec3(blended.x * 0.18, 1.0, blended.y * 0.18));
	vec3 normal = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);
	vec3 surface = get_view_position_from_uv(SCREEN_UV, FRAGCOORD.z, INV_PROJECTION_MATRIX);
	float raw = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	vec3 bottom = get_view_position_from_uv(SCREEN_UV, raw, INV_PROJECTION_MATRIX);
	vec3 bottom_world = (INV_VIEW_MATRIX * vec4(bottom, 1.0)).xyz;
	float depth = max(world_position.y - bottom_world.y, 0.0);
	vec2 refracted_uv = get_refracted_uv(SCREEN_UV, raw, VIEW, normal,
		PROJECTION_MATRIX, INV_PROJECTION_MATRIX);
	float refracted_raw = texture(DEPTH_TEXTURE, refracted_uv).r;
	vec3 refracted_bottom = get_view_position_from_uv(refracted_uv,
		refracted_raw, INV_PROJECTION_MATRIX);
	// Do not refract the character/bank in front of the water.
	if (refracted_bottom.z >= surface.z - 0.01) { refracted_uv = SCREEN_UV; }
	vec3 screen_color = texture(SCREEN_TEXTURE, refracted_uv).rgb;
	float visibility = exp(-min(depth, 80.0) * 0.65);
	vec3 tint = mix(color_shallow, color_deep, smoothstep(0.0, 4.5, depth));
	vec3 water_color = mix(tint, screen_color, visibility * 0.82);
	float fresnel = pow(1.0 - clamp(dot(normal, VIEW), 0.0, 1.0), 5.0);
	vec3 world_view = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 reflection = reflect(-world_view, world_normal);
	vec3 sky = mix(vec3(0.025, 0.040, 0.075), vec3(0.006, 0.012, 0.03),
		clamp(reflection.y, 0.0, 1.0));
	water_color = mix(water_color, sky, 0.1 + fresnel * 0.5);
	if (ssr_enabled && !ocean && length(surface) < 65.0) {
		vec4 ssr = get_ssr_color(surface, normal, VIEW, PROJECTION_MATRIX,
			INV_PROJECTION_MATRIX);
		if (ssr.x >= 0.0) {
			water_color = mix(water_color, ssr.rgb, ssr.a * (0.12 + fresnel * 0.4));
		}
	}
	float moon = pow(max(dot(reflection, normalize(moon_direction)), 0.0), 420.0);
	water_color += moon * vec3(0.26, 0.33, 0.46);
	float foam = (1.0 - smoothstep(0.04, 0.32, depth)) * 0.48;
	ALBEDO = mix(water_color, vec3(0.13, 0.18, 0.21), foam);
}
