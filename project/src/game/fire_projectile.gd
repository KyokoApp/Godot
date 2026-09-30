extends CharacterBody3D
## Fisika sweep tetap; visual arcane lama + ekor api world-space yang meluruh.

signal impacted(point: Vector3, normal: Vector3)

const FX = preload("res://src/game/attack_fx/fx_resources.gd")
const GRAVITY := Vector3(0, -12, 0)
const MAX_LIFETIME := 4.0
const TAIL_LIFETIME := 0.7

var age := 0.0
var finished := false
var _tail_age := 0.0
var _trail := Vector3.ZERO
var _flow := Vector3.ZERO
var _core: MeshInstance3D
var _shell: MeshInstance3D
var _flames: GPUParticles3D
var _sparks: GPUParticles3D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.11
	collision.shape = sphere
	add_child(collision)
	_core = FX.sphere(0.065, FX.CORE, 2.6)
	_core.name = "BoltCore"
	_core.material_override.set_shader_parameter("turbulence", 0.9)
	add_child(_core)
	_shell = FX.sphere(0.11, FX.SHELL, 1.5)
	_shell.name = "BoltFlameTail"
	_shell.material_override.set_shader_parameter("rise", 0.04)
	add_child(_shell)
	_flames = FX.particles("FireWake", 10, 0.55, false, true)
	_sparks = FX.particles("BoltSparks", 16, 0.32, false, false)
	add_child(_flames)
	add_child(_sparks)


func _process(delta: float) -> void:
	if finished:
		return
	_flow += velocity * delta * 0.5
	_trail = _trail.lerp((-velocity * 0.05).limit_length(0.9), 1.0 - exp(-13.0 * delta))
	_core.material_override.set_shader_parameter("flow_offset", _flow)
	_shell.material_override.set_shader_parameter("flow_offset", _flow)
	_shell.material_override.set_shader_parameter("trail", _trail)


func _physics_process(delta: float) -> void:
	if finished:
		_tail_age += delta
		if _tail_age >= TAIL_LIFETIME:
			queue_free()
		return
	age += delta
	if age >= MAX_LIFETIME:
		_finish()
		return
	# Sweep sphere, bukan sekadar cek posisi akhir: menghindari menembus collider tipis.
	var motion := velocity * delta + GRAVITY * (0.5 * delta * delta)
	velocity += GRAVITY * delta
	var collision := move_and_collide(motion, false, 0.005)
	if collision != null:
		_finish()
		impacted.emit(collision.get_position(), collision.get_normal())


func _finish() -> void:
	finished = true
	collision_layer = 0
	collision_mask = 0
	_core.hide()
	_shell.hide()
	_flames.emitting = false
	_sparks.emitting = false
