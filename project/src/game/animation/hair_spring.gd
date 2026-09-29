extends SkeletonModifier3D
## Bounded secondary rotation on Miku's two real nine-bone tails, not per-strand cloth.
## Local rest lengths stay unchanged. Native modifier restores poses after skinning.

const STEP := 1.0 / 120.0
const MAX_ANGLE := 0.11
var angles: Array[Vector2] = []
var velocities: Array[Vector2] = []
var bones: Array[int] = []
var _rest: Array[Quaternion] = []
var _previous_position := Vector3.ZERO
var _previous_forward := Vector3.FORWARD
var _previous_velocity := Vector3.ZERO
var _initialized := false


func configure() -> void:
	var skeleton := get_skeleton()
	for tail in ["07", "08"]:
		for segment in range(1, 9):
			var bone := skeleton.find_bone("J_Sec_Hair%d_%s" % [segment, tail])
			assert(bone >= 0, "Miku hair bone missing")
			bones.append(bone)
			_rest.append(skeleton.get_bone_rest(bone).basis.get_rotation_quaternion())
			angles.append(Vector2.ZERO)
			velocities.append(Vector2.ZERO)


func reset_motion() -> void:
	_initialized = false
	_previous_velocity = Vector3.ZERO
	for index in range(angles.size()):
		angles[index] = Vector2.ZERO
		velocities[index] = Vector2.ZERO


func simulate(delta: float, local_velocity: Vector3, acceleration: Vector3, turn: float) -> void:
	var drive := Vector2(local_velocity.z * 0.018 + acceleration.z * 0.0015,
		-local_velocity.x * 0.016 - acceleration.x * 0.0015 + turn * 0.022)
	drive = drive.limit_length(0.14)
	var remaining := minf(delta, 0.067)
	while remaining > 0.00001:
		var step := minf(STEP, remaining)
		remaining -= step
		for index in range(bones.size()):
			var segment := index % 8
			var upstream := Vector2.ZERO if segment == 0 else angles[index - 1]
			var target := drive * (0.75 if segment == 0 else 0.18) + upstream * 0.68
			var stiffness := 85.0 - segment * 5.0
			velocities[index] += (target - angles[index]) * stiffness * step
			velocities[index] *= exp(-9.0 * step)
			angles[index] = (angles[index] + velocities[index] * step).limit_length(MAX_ANGLE)


func _process_modification_with_delta(delta: float) -> void:
	if bones.is_empty() or delta <= 0:
		return
	var skeleton := get_skeleton()
	var head := skeleton.find_bone("J_Bip_C_Head")
	var anchor := skeleton.global_transform * skeleton.get_bone_global_pose(head)
	var position := anchor.origin
	var forward := -anchor.basis.orthonormalized().z
	if not _initialized or delta > 0.12 or position.distance_to(_previous_position) > 2.5:
		reset_motion()
		_previous_position = position
		_previous_forward = forward
		_initialized = true
	var velocity := ((position - _previous_position) / maxf(delta, 0.001)).limit_length(10)
	velocity.y = 0
	var acceleration := ((velocity - _previous_velocity) / maxf(delta, 0.001)).limit_length(30)
	var turn := _previous_forward.signed_angle_to(forward, Vector3.UP) / maxf(delta, 0.001)
	var inverse := skeleton.global_basis.orthonormalized().inverse()
	simulate(delta, inverse * velocity, inverse * acceleration, clampf(turn, -6, 6))
	_previous_position = position
	_previous_forward = forward
	_previous_velocity = velocity
	for index in range(bones.size()):
		var angle := angles[index]
		skeleton.set_bone_pose_rotation(bones[index], _rest[index]
			* Quaternion.from_euler(Vector3(angle.x, 0, angle.y)))
