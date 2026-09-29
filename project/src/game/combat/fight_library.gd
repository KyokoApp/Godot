extends RefCounted
## Combat animations from the already-loaded UAL1 rig.
## No extra GLB or skeleton retarget needed.
const PUNCH := "Punch_Cross"
const PUNCH_ALT := "Punch_Jab"
const SWORD := "Sword_Attack"
const HIT := "Hit_Chest"
const HIT_HEAD := "Hit_Head"
const DEATH := "Death01"
const IDLE := "Idle_Loop"


static func install(player: AnimationPlayer) -> bool:
	if player.has_animation_library("combat"):
		return true
	# All clips are already in the default library from the UAL1 import.
	for clip in [PUNCH, HIT, DEATH]:
		if not player.has_animation(clip):
			push_error("Combat anim hilang: " + clip)
			return false
	var library := AnimationLibrary.new()
	for clip in [PUNCH, PUNCH_ALT, SWORD, HIT, HIT_HEAD, DEATH, IDLE]:
		if player.has_animation(clip):
			var anim := player.get_animation(clip).duplicate(true)
			anim.loop_mode = Animation.LOOP_NONE
			library.add_animation(clip, anim)
	player.add_animation_library("combat", library)
	return true
