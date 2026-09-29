extends Node
## Drives UAL2 clips on their imported rig, then copies the pose to the game rig.
## This keeps every AnimationPlayer track path inside its original GLB scene.
const MODEL = preload("res://assets/combat/UAL2_Standard.glb")
const PUNCH := "Melee_Hook"
const HIT := "Hit_Knockback"
const REQUIRED_CLIPS := [
	"Melee_Hook",
	"Hit_Knockback",
	"Sword_Regular_Combo",
	"Zombie_Scratch",
	"Slide_Start",
	"NinjaJump_Start",
]

var animation: AnimationPlayer
var source_skeleton: Skeleton3D
var target_skeleton: Skeleton3D
var _model: Node3D
var _bone_pairs: Array[Vector2i] = []


func setup(target: Skeleton3D) -> bool:
	if target == null:
		return false
	target_skeleton = target
	_model = MODEL.instantiate() as Node3D
	if _model == null:
		return _fail_setup("UAL2 model failed to instantiate")
	_model.name = "UAL2FightAnimationSource"
	_model.visible = false
	animation = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	source_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if animation == null or source_skeleton == null:
		return _fail_setup("UAL2 rig or AnimationPlayer is missing")
	for source_bone in range(source_skeleton.get_bone_count()):
		var bone_name := source_skeleton.get_bone_name(source_bone)
		var target_bone := target.find_bone(bone_name)
		if target_bone < 0 or not target.get_bone_rest(target_bone).is_equal_approx(
				source_skeleton.get_bone_rest(source_bone)):
			return _fail_setup("UAL2 rig mismatch at bone: " + bone_name)
		_bone_pairs.append(Vector2i(source_bone, target_bone))
	if _bone_pairs.size() != target.get_bone_count():
		return _fail_setup("UAL2 target rig has a different bone count")
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	add_child(_model)
	return true


func _fail_setup(message: String) -> bool:
	push_error(message)
	if is_instance_valid(_model):
		_model.free()
	_model = null
	animation = null
	source_skeleton = null
	target_skeleton = null
	_bone_pairs.clear()
	return false


func has_clip(clip: String) -> bool:
	var imported := _resolve_clip(clip)
	return animation != null and not imported.is_empty() and animation.has_animation(imported)


func play(clip: String) -> float:
	var imported := _resolve_clip(clip)
	if animation == null or imported.is_empty() or not animation.has_animation(imported):
		return 0.0
	animation.speed_scale = 1.0
	animation.play(imported, 0.12)
	animation.advance(0.0)
	return animation.get_animation(imported).length


func _resolve_clip(clip: String) -> String:
	if animation == null:
		return ""
	if animation.has_animation(clip):
		return clip
	var without_loop := clip.trim_suffix("_Loop")
	return without_loop if animation.has_animation(without_loop) else ""


func advance(delta: float) -> void:
	if animation == null or source_skeleton == null:
		return
	animation.advance(delta)
	sync_pose()


func sync_pose() -> void:
	if not is_instance_valid(source_skeleton) or not is_instance_valid(target_skeleton):
		return
	for pair in _bone_pairs:
		target_skeleton.set_bone_pose_position(
			pair.y, source_skeleton.get_bone_pose_position(pair.x))
		target_skeleton.set_bone_pose_rotation(
			pair.y, source_skeleton.get_bone_pose_rotation(pair.x))
		target_skeleton.set_bone_pose_scale(
			pair.y, source_skeleton.get_bone_pose_scale(pair.x))


func stop() -> void:
	if animation != null:
		animation.stop()
