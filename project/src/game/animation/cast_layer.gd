extends SkeletonModifier3D
## Post-locomotion upper-body layer; Skeleton3D restores the base pose afterward.
## Keep the original AnimationPlayer clock intact for footstep timing.

const CLIP := "Spell_Simple_Shoot"
const RELEASE_TIME := 0.16
const HOLD_POSE_TIME := 0.20
const HOLD_RELEASE_DELAY := 0.42
const FADE_IN := 0.08
const FADE_OUT := 0.14

var clip: Animation
var elapsed := 0.0
var playing := false
var holding_pose := false
var tracks: Dictionary[int, int] = {}
var _hold_release_left := 0.0


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
	holding_pose = false
	_hold_release_left = 0.0
	elapsed = 0.0
	playing = true
	active = true
	influence = 0.0


func begin_held() -> void:
	if clip == null or tracks.is_empty():
		return
	_hold_release_left = HOLD_RELEASE_DELAY
	if holding_pose and playing:
		return
	# Mainkan bagian menaikkan tangan sekali, lalu tahan pose di frame 0,20 dtk.
	# Panggilan tembakan berulang tidak mengulang animasi dari awal.
	holding_pose = true
	elapsed = 0.0
	playing = true
	active = true
	influence = 0.0


func end_held() -> void:
	# Setelah input tembakan berhenti, sisa klip berjalan lagi sehingga tangan
	# turun lewat animasi aslinya, bukan dipotong mendadak.
	holding_pose = false
	_hold_release_left = 0.0


func cancel() -> void:
	holding_pose = false
	_hold_release_left = 0.0
	playing = false
	active = false
	influence = 0.0
	elapsed = 0.0


func _process(delta: float) -> void:
	if not holding_pose or not playing:
		return
	_hold_release_left = maxf(0.0, _hold_release_left - delta)
	if _hold_release_left <= 0.0:
		end_held()


func _physics_process(delta: float) -> void:
	if not playing:
		return
	if holding_pose:
		elapsed = minf(elapsed + delta, HOLD_POSE_TIME)
		influence = smoothstep(0.0, FADE_IN, elapsed)
		if elapsed >= HOLD_POSE_TIME:
			influence = 1.0
		return
	elapsed = minf(elapsed + delta, clip.length)
	influence = minf(smoothstep(0, FADE_IN, elapsed),
		smoothstep(0, FADE_OUT, clip.length - elapsed))
	if elapsed >= clip.length:
		playing = false
		active = false
		influence = 0.0
		holding_pose = false
		_hold_release_left = 0.0


func _process_modification_with_delta(_delta: float) -> void:
	if not playing or clip == null:
		return
	var skeleton := get_skeleton()
	for track: int in tracks:
		# Native modifier influence supplies the fade; don't blend it twice.
		skeleton.set_bone_pose_rotation(tracks[track],
			clip.rotation_track_interpolate(track, elapsed))
