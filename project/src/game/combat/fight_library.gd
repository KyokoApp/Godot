extends RefCounted
## Combat clip names from the already-loaded UAL1 rig.
## No extra GLB, library, or skeleton retarget.
const PUNCH := "Punch_Cross"
const PUNCH_ALT := "Punch_Jab"
const SWORD := "Sword_Attack"
const HIT := "Hit_Chest"
const HIT_HEAD := "Hit_Head"
const DEATH := "Death01"


static func available(player: AnimationPlayer) -> bool:
	return player.has_animation(PUNCH) and player.has_animation(HIT)


static func play(player: AnimationPlayer, clip: String,
		cast_layer, speed: float = 1.0) -> float:
	if not player.has_animation(clip):
		return 0.0
	if cast_layer != null:
		cast_layer.playing = false
		cast_layer.active = false
		cast_layer.influence = 0.0
	player.speed_scale = speed
	player.play(clip, 0.15)
	return player.get_animation(clip).length
