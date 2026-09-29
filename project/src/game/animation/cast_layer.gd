extends SkeletonModifier3D
## Post-locomotion upper-body layer; Skeleton3D restores the base pose afterward.
## Keep the original AnimationPlayer clock intact for footstep timing.

const CLIP := "Spell_Simple_Shoot"
const RELEASE_TIME := 0.16
const FADE_IN := 0.08
const FADE_OUT := 0.14

var clip: Animation
var elapsed := 0.0
var playing := false
var tracks: Dictionary[int, int] = {}


func configure(source: Animation) -> void:
	clip = source
	var skeleton := get_skeleton()
	var spine := skeleton.find_bone("spine_01")
	for track in range(clip.get_track_count()):
		if clip.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var path := clip.track_get_path(track)
		if path.get_subname_count() != 1:
			continue
		var bone := skeleton.find_bone(path.get_subname(0))
		var ancestor := bone
		while ancestor >= 0 and ancestor != spine:
			ancestor = skeleton.get_bone_parent(ancestor)
		if spine >= 0 and ancestor == spine:
			tracks[track] = bone
	active = false
	influence = 0.0


func begin() -> void:
	if clip == null or tracks.is_empty():
		return
	elapsed = 0.0
	playing = true
	active = true
	influence = 0.0


func _physics_process(delta: float) -> void:
	if not playing:
		return
	elapsed = minf(elapsed + delta, clip.length)
	influence = minf(smoothstep(0, FADE_IN, elapsed),
		smoothstep(0, FADE_OUT, clip.length - elapsed))
	if elapsed >= clip.length:
		playing = false
		active = false
		influence = 0.0


func _process_modification_with_delta(_delta: float) -> void:
	if not playing or clip == null:
		return
	var skeleton := get_skeleton()
	for track: int in tracks:
		# Native modifier influence supplies the fade; don't blend it twice.
		skeleton.set_bone_pose_rotation(tracks[track],
			clip.rotation_track_interpolate(track, elapsed))
