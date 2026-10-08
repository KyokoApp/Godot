extends CharacterBody3D
## Proyektil sihir lama: sweep fisika, ekor api world-space, dan homing bila dikunci.

signal impacted(point: Vector3, normal: Vector3)

const FX = preload("res://src/game/attack_fx/fx_resources.gd")
const GRAVITY := Vector3(0, -12, 0)
const HOMING_SPEED := 22.0
const HOMING_TURN_RATE := 9.0
const HOMING_AIM_OFFSET := Vector3(0, 0.72, 0)
const MAX_LIFETIME := 4.0
const TAIL_LIFETIME := 0.7

var age := 0.0
var finished := false
var homing_target: Node3D
var homing_speed := HOMING_SPEED
var homing_turn_rate := HOMING_TURN_RATE
var impact_collider: Object
var _tail_age := 0.0
var _trail := Vector3.ZERO
var _flow := Vector3.ZERO
var _core: MeshInstance3D
var _shell: MeshInstance3D
var _flames: GPUParticles3D


func _ready() -> void:
	# Bit 8 khusus projectile, supaya proyektil tidak saling menabrak.
	collision_layer = 8
	# Bit 1 = terrain, bit 4 = zombie.
	collision_mask = 1 | 4
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.085
	collision.shape = sphere
	add_child(collision)
	_core = FX.sphere(0.040, FX.CORE, 1.7, 10, 6)
	_core.name = "BoltCore"
	_core.material_override.set_shader_parameter("turbulence", 0.65)
	add_child(_core)
	_shell = FX.sphere(0.075, FX.SHELL, 0.95, 10, 6)
	_shell.name = "BoltFlameTail"
	_shell.material_override.set_shader_parameter("rise", 0.04)
	add_child(_shell)
	_flames = FX.particles("FireWake", 4, 0.34, false, true)
	var flame_shape := _flames.process_material as ParticleProcessMaterial
	flame_shape.scale_min = 0.30
	flame_shape.scale_max = 0.48
	var flame_quad := _flames.draw_pass_1 as QuadMesh
	flame_quad.size = Vector2(0.22, 0.36)
	add_child(_flames)


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
	# Saat dikunci, arah terus diperbarui ke posisi monster; tanpa target, lintasan
	# balistik lama tetap dipakai. Sweep sphere mencegah peluru menembus collider.
	var motion: Vector3
	if _has_live_homing_target():
		var aim := homing_target.global_position + HOMING_AIM_OFFSET
		var toward_target := aim - global_position
		var desired_direction := toward_target.normalized()
		var speed := maxf(velocity.length(), homing_speed)
		if velocity.length_squared() > 0.001:
			var turn := 1.0 - exp(-homing_turn_rate * delta)
			desired_direction = velocity.normalized().lerp(desired_direction, turn).normalized()
		if desired_direction.length_squared() < 0.001:
			desired_direction = toward_target.normalized()
		velocity = desired_direction * speed
		motion = velocity * delta
	else:
		homing_target = null
		motion = velocity * delta + GRAVITY * (0.5 * delta * delta)
		velocity += GRAVITY * delta
	var collision := move_and_collide(motion, false, 0.005)
	if collision != null:
		impact_collider = collision.get_collider()
		_finish()
		impacted.emit(collision.get_position(), collision.get_normal())


func _has_live_homing_target() -> bool:
	if not is_instance_valid(homing_target):
		return false
	if homing_target.has_method("can_be_targeted") \
			and not bool(homing_target.call("can_be_targeted")):
		return false
	return true


func _finish() -> void:
	finished = true
	collision_layer = 0
	collision_mask = 0
	_core.hide()
	_shell.hide()
	_flames.emitting = false
