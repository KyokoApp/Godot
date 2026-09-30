extends Node
## Drives clips on the imported UAL2 rig and copies poses to a matching game rig.
## Names are taken from UAL2_Standard.glb's glTF animation list.
const MODEL = preload("res://assets/combat/UAL2_Standard.glb")

# Backwards-compatible defaults used by the original arena challenge and tests.
const MELEE := "Melee_Hook"
const PUNCH := MELEE
const SWORD := "Sword_Regular_Combo"
const HIT := "Hit_Knockback"

# UAL2 unarmed attacks and their transition/recovery.
const MELEE_HOOK := "Melee_Hook"
const MELEE_HOOK_RECOVERY := "Melee_Hook_Rec"
const ZOMBIE_SCRATCH := "Zombie_Scratch"
const OVERHAND_THROW := "OverhandThrow"

# UAL2 sword attacks, combo links, and defensive actions.
const SWORD_REGULAR_COMBO := "Sword_Regular_Combo"
const SWORD_REGULAR_A := "Sword_Regular_A"
const SWORD_REGULAR_A_RECOVERY := "Sword_Regular_A_Rec"
const SWORD_REGULAR_B := "Sword_Regular_B"
const SWORD_REGULAR_B_RECOVERY := "Sword_Regular_B_Rec"
const SWORD_REGULAR_C := "Sword_Regular_C"
const SWORD_HEAVY_COMBO := "Sword_Heavy_Combo"
const SWORD_BLOCK := "Sword_Block"
const SWORD_DASH := "Sword_Dash"

# UAL2 shield actions. (The arena uses them for the opponent's guard/dash moves.)
const SHIELD_DASH := "Shield_Dash"
const SHIELD_ONE_SHOT := "Shield_OneShot"
const IDLE_SHIELD_BREAK := "Idle_Shield_Break"
const IDLE_SHIELD_LOOP := "Idle_Shield_Loop"

# UAL2 movement/evasion and get-up/reaction animations.
const SLIDE_START := "Slide_Start"
const SLIDE_LOOP := "Slide_Loop"
const SLIDE_EXIT := "Slide_Exit"
const NINJA_JUMP_START := "NinjaJump_Start"
const NINJA_JUMP_IDLE_LOOP := "NinjaJump_Idle_Loop"
const NINJA_JUMP_LAND := "NinjaJump_Land"
const ZOMBIE_IDLE_LOOP := "Zombie_Idle_Loop"
const ZOMBIE_WALK_LOOP := "Zombie_Walk_Fwd_Loop"
const HIT_KNOCKBACK := "Hit_Knockback"
const LAY_TO_IDLE := "LayToIdle"

## Every combat, combat-reaction, and combat-mobility clip in the shipped UAL2 file.
## Deliberately excludes unrelated farming, climbing, and emote clips.
const REQUIRED_CLIPS := [
	HIT_KNOCKBACK,
	IDLE_SHIELD_BREAK,
	IDLE_SHIELD_LOOP,
	LAY_TO_IDLE,
	MELEE_HOOK,
	MELEE_HOOK_RECOVERY,
	OVERHAND_THROW,
	NINJA_JUMP_IDLE_LOOP,
	NINJA_JUMP_LAND,
	NINJA_JUMP_START,
	SHIELD_DASH,
	SHIELD_ONE_SHOT,
	SLIDE_EXIT,
	SLIDE_LOOP,
	SLIDE_START,
	SWORD_BLOCK,
	SWORD_DASH,
	SWORD_HEAVY_COMBO,
	SWORD_REGULAR_A,
	SWORD_REGULAR_A_RECOVERY,
	SWORD_REGULAR_B,
	SWORD_REGULAR_B_RECOVERY,
	SWORD_REGULAR_C,
	SWORD_REGULAR_COMBO,
	ZOMBIE_IDLE_LOOP,
	ZOMBIE_SCRATCH,
	ZOMBIE_WALK_LOOP,
]

const MELEE_CLIPS := [MELEE_HOOK, ZOMBIE_SCRATCH]
const RANGED_ATTACK_CLIPS := [OVERHAND_THROW]
const SWORD_ATTACK_CLIPS := [
	SWORD_REGULAR_COMBO,
	SWORD_REGULAR_A,
	SWORD_REGULAR_B,
	SWORD_REGULAR_C,
	SWORD_HEAVY_COMBO,
]
const SWORD_RECOVERY_CLIPS := [SWORD_REGULAR_A_RECOVERY, SWORD_REGULAR_B_RECOVERY]
const EVADE_CLIPS := [SLIDE_START, NINJA_JUMP_START]
const FIGHT_REACTION_CLIPS := [HIT_KNOCKBACK, IDLE_SHIELD_BREAK, LAY_TO_IDLE]

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


func missing_required_clips() -> PackedStringArray:
	var missing := PackedStringArray()
	for clip: String in REQUIRED_CLIPS:
		if not has_clip(clip):
			missing.append(clip)
	return missing


func clip_length(clip: String) -> float:
	var imported := _resolve_clip(clip)
	if animation == null or imported.is_empty() or not animation.has_animation(imported):
		return 0.0
	return animation.get_animation(imported).length


func play(clip: String) -> float:
	var imported := _resolve_clip(clip)
	if animation == null or imported.is_empty() or not animation.has_animation(imported):
		return 0.0
	animation.speed_scale = 1.0
	animation.play(imported, 0.12)
	animation.advance(0.0)
	return animation.get_animation(imported).length


func play_loop(clip: String) -> bool:
	var imported := _resolve_clip(clip)
	if animation == null or imported.is_empty() or not animation.has_animation(imported):
		return false
	animation.get_animation(imported).loop_mode = Animation.LOOP_LINEAR
	animation.speed_scale = 1.0
	animation.play(imported, 0.12)
	animation.advance(0.0)
	return true


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
