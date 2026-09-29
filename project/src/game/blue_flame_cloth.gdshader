shader_type spatial;
render_mode cull_disabled, diffuse_toon, specular_disabled;

// Kain opaque: menutupi rig, tanpa overdraw transparansi atau lampu per api.
uniform vec3 cloth_color : source_color = vec3(0.32, 0.60, 0.78);
uniform vec3 flame_color : source_color = vec3(0.66, 0.89, 0.96);

void fragment() {
	float tongue = 0.72 + sin(UV.x * 31.4159 + TIME * 1.5) * 0.09
		+ sin(UV.x * 56.5487 - TIME * 1.1) * 0.04;
	float flame = smoothstep(tongue - 0.04, tongue + 0.08, UV.y);
	float folds = 0.94 + 0.06 * cos(UV.x * 50.2655);
	ALBEDO = mix(cloth_color * folds, flame_color, flame);
	EMISSION = flame_color * flame * 0.09;
	ROUGHNESS = 1.0;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
