extends Node3D
## Ledakan bulat bertahap: inti membesar, lidah api berputar, lalu menyusut.

const Visual = preload("res://src/game/fire_visual.gd")
const LIFETIME := 1.0
const MAX_RADIUS := 1.9

var age := 0.0
var _ring: MeshInstance3D
var _core: MeshInstance3D
var _flames: Array[MeshInstance3D] = []


func _ready() -> void:
	_core = Visual.make_orb(0.1)
	add_child(_core)
	_core.extra_cull_margin = 1.2
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.94
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 6
	_ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("8c98ff")
	_ring.material_override = material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.position.y = -0.65
	add_child(_ring)
	for index in range(8):
		var flame := Visual.make_orb(0.12)
		add_child(flame)
		flame.extra_cull_margin = 0.7
		_flames.append(flame)


func _process(delta: float) -> void:
	age += delta
	if age >= LIFETIME:
		queue_free()
		return
	var expand := 1.0 - pow(1.0 - clampf(age / 0.24, 0.0, 1.0), 3.0)
	var vanish := 1.0 - smoothstep(0.48, LIFETIME, age)
	var radius := maxf(0.001, MAX_RADIUS * expand * vanish)
	_core.scale = Vector3.ONE * radius
	_core.rotation.y += delta * 4.0
	_ring.scale = Vector3.ONE * maxf(0.001, (0.2 + age * 3.4) * vanish)
	for index in range(_flames.size()):
		var angle := index * TAU / _flames.size() + age * 5.0
		var elevation := sin(index * 2.4 + age * 3.0) * 0.75
		var normal := Vector3(cos(angle), elevation, sin(angle)).normalized()
		var flame := _flames[index]
		flame.position = normal * radius * 0.9
		flame.scale = Vector3(0.28, 0.55, 0.28) * radius
		flame.rotation = Vector3(sin(angle) * 0.7, angle, cos(angle) * 0.7)
