extends SkeletonModifier3D
## Last modifier on the UAL skeleton: reads the FINAL, blended casting pose.
## Adapted from the project's old Kanna rest-space retarget, not raw bone copying.

const Rig = preload("res://src/game/animation/miku_rig.gd")

var target: Skeleton3D
var pairs: Array[Vector2i] = []
var transfers := 0
var _source_rest: Dictionary[int, Quaternion] = {}
var _target_rest: Dictionary[int, Quaternion] = {}
var _target_local: Array[Quaternion] = []
var _hips := Vector2i(-1, -1)
var _source_hips := Vector3.ZERO
var _target_hips := Vector3.ZERO
var _height_ratio := 1.0


func configure(destination: Skeleton3D, mapping: Array = Rig.PAIRS) -> bool:
	target = destination
	var source := get_skeleton()
	for names: Array in mapping:
		var from := source.find_bone(names[0])
		var to := target.find_bone(names[1])
		if from < 0 or to < 0:
			push_error("Skin retarget: tulang hilang: " + str(names))
			return false
		pairs.append(Vector2i(from, to))
		_source_rest[from] = source.get_bone_global_rest(from).basis.get_rotation_quaternion()
		_target_rest[to] = target.get_bone_global_rest(to).basis.get_rotation_quaternion()
		if names[0] == "pelvis":
			_hips = Vector2i(from, to)
			_source_hips = source.get_bone_global_rest(from).origin
			_target_hips = target.get_bone_global_rest(to).origin
			_height_ratio = _target_hips.y / maxf(_source_hips.y, 0.01)
	for bone in range(target.get_bone_count()):
		_target_local.append(target.get_bone_rest(bone).basis.get_rotation_quaternion())
	transfer()
	return pairs.size() == mapping.size()


func _process_modification_with_delta(_delta: float) -> void:
	transfer()


func _global_rotation(bone: int, rotations: Dictionary[int, Quaternion],
		cache: Dictionary[int, Quaternion]) -> Quaternion:
	if bone < 0:
		return Quaternion.IDENTITY
	if cache.has(bone):
		return cache[bone]
	var parent := _global_rotation(target.get_bone_parent(bone), rotations, cache)
	var rotation: Quaternion = rotations.get(bone, parent * _target_local[bone])
	cache[bone] = rotation.normalized()
	return cache[bone]


func transfer() -> void:
	if not is_instance_valid(target) or pairs.is_empty():
		return
	var source := get_skeleton()
	var rotations: Dictionary[int, Quaternion] = {}
	var cache: Dictionary[int, Quaternion] = {}
	for pair in pairs:
		var pose := source.get_bone_global_pose(pair.x).basis.orthonormalized()
		var delta := pose.get_rotation_quaternion() * _source_rest[pair.x].inverse()
		# UAL left is +X; VRM left is -X. Conjugate by a 180-degree Y rotation.
		var corrected := Quaternion(-delta.x, delta.y, -delta.z, delta.w)
		rotations[pair.y] = (corrected * _target_rest[pair.y]).normalized()
	for pair in pairs:
		var parent := _global_rotation(target.get_bone_parent(pair.y), rotations, cache)
		target.set_bone_pose_rotation(pair.y, (parent.inverse() * rotations[pair.y]).normalized())
	# Preserve target bone lengths; only scale the hip's translation from rest.
	var offset := (source.get_bone_global_pose(_hips.x).origin - _source_hips) * _height_ratio
	var position := _target_hips + Vector3(-offset.x, offset.y, -offset.z)
	var parent := target.get_bone_parent(_hips.y)
	if parent >= 0:
		var basis := Basis(_global_rotation(parent, rotations, cache))
		position = basis.inverse() * (position - target.get_bone_global_rest(parent).origin)
	target.set_bone_pose_position(_hips.y, position)
	transfers += 1
