extends Node3D
## Impact berlapis: dua selubung api berpilin, lidah api, percikan, lalu bara.

const FX = preload("res://src/game/attack_fx/fx_resources.gd")
const SHOCKWAVE = preload("res://src/game/attack_fx/shockwave.gdshader")
const LIFETIME := 1.9
const MAX_RADIUS := 1.6

var age := 0.0
var surface_normal := Vector3.UP
var _ring: MeshInstance3D
var _inner: MeshInstance3D
var _outer: MeshInstance3D
var _flash: OmniLight3D


func _ready() -> void:
	surface_normal = surface_normal.normalized()
	if surface_normal.is_zero_approx():
		surface_normal = Vector3.UP
	_inner = FX.sphere(0.75, FX.SHELL, 1.8)
	_inner.name = "HotFlame"
	_outer = FX.sphere(1.0, FX.SHELL, 1.3)
	_outer.name = "OuterFlame"
	for shell in [_inner, _outer]:
		shell.position = surface_normal * 0.45
		shell.scale = Vector3.ONE * 0.03
		shell.material_override.set_shader_parameter("rise", 0.45)
		add_child(shell)
	_inner.rotation.z = 0.6
	var fire := FX.particles("FlamePetals", 18, 0.9, true, true)
	fire.position = surface_normal * 0.4
	add_child(fire)
	add_child(FX.particles("ImpactSparks", 24, 1.15, true, false))
	var embers := FX.particles("CoolingEmbers", 8, 1.65, true, false)
	var ember_motion := embers.process_material as ParticleProcessMaterial
	ember_motion.initial_velocity_min = 0.5
	ember_motion.initial_velocity_max = 2.0
	ember_motion.gravity = Vector3(0, 0.4, 0)
	add_child(embers)
	_make_ring()
	_flash = OmniLight3D.new()
	_flash.name = "ImpactFlash"
	_flash.light_color = Color(0.55, 0.42, 1.0)
	_flash.omni_range = 5.0
	_flash.shadow_enabled = false
	_flash.position = surface_normal * 0.6
	add_child(_flash)
	_update_visuals()


func _make_ring() -> void:
	_ring = MeshInstance3D.new()
	_ring.name = "SurfaceShockwave"
	var plane := PlaneMesh.new()
	plane.size = Vector2(5, 5)
	_ring.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = SHOCKWAVE
	material.set_shader_parameter("energy", 1.2)
	_ring.material_override = material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tangent := surface_normal.cross(Vector3.FORWARD)
	if tangent.length_squared() < 0.01:
		tangent = surface_normal.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	_ring.basis = Basis(tangent, surface_normal, tangent.cross(surface_normal))
	_ring.position = surface_normal * 0.03
	add_child(_ring)


func _process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	_update_visuals()


func _update_visuals() -> void:
	var expand := 1.0 - pow(1.0 - clampf(age / 0.22, 0.0, 1.0), 3.0)
	_outer.scale = Vector3.ONE * maxf(0.03, MAX_RADIUS * expand)
	_inner.scale = _outer.scale * 0.85
	_outer.rotation.y = age * 2.8
	_inner.rotation.y = -age * 4.0
	_outer.position = surface_normal * (0.45 + age * 0.25)
	_outer.material_override.set_shader_parameter("flow_offset", Vector3(0, -age * 2, 0))
	_inner.material_override.set_shader_parameter("flow_offset", Vector3(age, -age * 3, 1))
	_outer.material_override.set_shader_parameter("alpha_scale", 1.0 - smoothstep(0.2, 0.9, age))
	_inner.material_override.set_shader_parameter("alpha_scale", 1.0 - smoothstep(0.08, 0.5, age))
	_outer.visible = age < 0.9
	_inner.visible = age < 0.5
	_ring.visible = age < 0.5
	_ring.material_override.set_shader_parameter("progress", clampf(age / 0.5, 0, 1))
	_flash.light_energy = 3.0 * pow(1.0 - clampf(age / 0.28, 0, 1), 2.0)
	_flash.visible = age < 0.28
