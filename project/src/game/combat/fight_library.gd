extends RefCounted
## UAL2 non-root-motion clips; same Quaternius rig as the existing UAL1 driver.
const MODEL = preload("res://assets/combat/UAL2_Standard.glb")
const CLIPS := ["Hit_Knockback", "Idle_Shield_Break", "Idle_Shield_Loop",
	"Melee_Hook", "Melee_Hook_Rec", "OverhandThrow", "Shield_Dash",
	"Shield_OneShot", "Sword_Block", "Sword_Dash", "Sword_Heavy_Combo",
	"Sword_Regular_A", "Sword_Regular_A_Rec", "Sword_Regular_B",
	"Sword_Regular_B_Rec", "Sword_Regular_C", "Sword_Regular_Combo",
	"Zombie_Idle_Loop", "Zombie_Scratch", "Zombie_Walk_Fwd_Loop",
	"NinjaJump_Idle_Loop", "NinjaJump_Land", "NinjaJump_Start",
	"Slide_Exit", "Slide_Loop", "Slide_Start"]


static func install(player: AnimationPlayer,
		target: Skeleton3D) -> bool:
	if player.has_animation_library("fight"):
		return true
	var model: Node3D = MODEL.instantiate()
	var source := model.find_child("AnimationPlayer",
		true, false) as AnimationPlayer
	var src_skel := model.find_child("Skeleton3D",
		true, false) as Skeleton3D
	if source == null or src_skel == null:
		model.free()
		return false
	for bone in range(target.get_bone_count()):
		var other := src_skel.find_bone(
			target.get_bone_name(bone))
		if other < 0 or not target.get_bone_rest(
				bone).is_equal_approx(
				src_skel.get_bone_rest(other)):
			push_error("UAL2: rest mismatch: "
				+ target.get_bone_name(bone))
			model.free()
			return false
	var library := AnimationLibrary.new()
	var root := player.get_node(player.root_node)
	var prefix := str(root.get_path_to(target))
	for name in CLIPS:
		var imported: String = name 			if source.has_animation(name) 			else name.trim_suffix("_Loop")
		if not source.has_animation(imported):
			push_error("UAL2 missing: " + name)
			model.free()
			return false
		var clip := source.get_animation(
			imported).duplicate(true) as Animation
		for track in range(
				clip.get_track_count() - 1, 0 - 1, -1):
			var path := clip.track_get_path(track)
			if path.get_subname_count() != 1:
				clip.remove_track(track)
				continue
			var bone := str(path.get_subname(0))
			if target.find_bone(bone) < 0:
				clip.remove_track(track)
				continue
			clip.track_set_path(track,
				NodePath(prefix + ":" + bone))
		clip.loop_mode = Animation.LOOP_LINEAR 			if name.ends_with("Loop") 			else Animation.LOOP_NONE
		library.add_animation(name, clip)
	model.free()
	player.add_animation_library("fight", library)
	return true
