extends Node3D
## Gelombang skill satu-mesh; menggantikan burst partikel yang berat untuk AoE.

const SHOCKWAVE = preload("res://src/game/attack_fx/shockwave.gdshader")
const DEFAULT_DURATION := 0.48

var radius := 3.0
var duration := DEFAULT_DURATION
var tint := Color("#ff925e")
var energy := 1.0
var age := 0.0
var _material: ShaderMaterial


func _ready() -> void:
	name = "SkillWave"
	process_mode = Node.PROCESS_MODE_ALWAYS
	var ring := MeshInstance3D.new()
	ring.name = "WaveRing"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * maxf(0.1, radius * 2.0)
	ring.mesh = plane
	ring.rotation.x = -PI * 0.5
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = SHOCKWAVE
	_material.set_shader_parameter("tint", tint)
	_material.set_shader_parameter("energy", energy)
	_material.set_shader_parameter("progress", 0.0)
	ring.material_override = _material
	add_child(ring)
	set_process(true)


func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		queue_free()
		return
	_material.set_shader_parameter("progress", clampf(age / maxf(duration, 0.01), 0.0, 1.0))
