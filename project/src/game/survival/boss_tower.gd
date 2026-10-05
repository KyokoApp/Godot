extends Node3D
## Monumen sederhana yang menandai pilihan lanjut setelah stage kelipatan lima.

var activated := false
var _clock := 0.0
var _pulse_material: StandardMaterial3D
var _spire_material: StandardMaterial3D


func _ready() -> void:
	name = "StageGateTower"
	_build_meshes()


func _process(delta: float) -> void:
	_clock += delta
	rotation.y = _clock * 0.42
	if _pulse_material != null:
		_pulse_material.emission_energy_multiplier = 0.75 + 0.25 * sin(_clock * 2.2)
	if _spire_material != null:
		_spire_material.emission_energy_multiplier = 0.90 + 0.35 * sin(_clock * 1.7 + 0.6)


func _build_meshes() -> void:
	var base := MeshInstance3D.new()
	base.name = "TowerBase"
	var base_shape := CylinderMesh.new()
	base_shape.top_radius = 0.88
	base_shape.bottom_radius = 1.12
	base_shape.height = 1.1
	base_shape.radial_segments = 8
	base.mesh = base_shape
	base.position.y = 0.55
	base.material_override = _material(Color("#503b77"), Color("#291e47"), 0.5)
	base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(base)

	var ring := MeshInstance3D.new()
	ring.name = "TowerRuneRing"
	var ring_shape := TorusMesh.new()
	ring_shape.inner_radius = 0.68
	ring_shape.outer_radius = 0.78
	ring_shape.rings = 8
	ring_shape.ring_segments = 20
	ring.mesh = ring_shape
	ring.position.y = 1.15
	_pulse_material = _material(Color("#c193ff"), Color("#9b5cff"), 2.2)
	ring.material_override = _pulse_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	var spire := MeshInstance3D.new()
	spire.name = "TowerSpire"
	var spire_shape := CylinderMesh.new()
	spire_shape.top_radius = 0.03
	spire_shape.bottom_radius = 0.55
	spire_shape.height = 1.8
	spire_shape.radial_segments = 8
	spire.mesh = spire_shape
	spire.position.y = 2.05
	_spire_material = _material(Color("#f1d69a"), Color("#e7a7ff"), 1.6)
	spire.material_override = _spire_material
	spire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(spire)


func _material(color: Color, glow: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = glow
	material.emission_energy_multiplier = energy
	return material
