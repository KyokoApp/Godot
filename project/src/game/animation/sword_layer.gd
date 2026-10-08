extends SkeletonModifier3D
## Lapisan serangan pedang di tubuh atas. Animasi gait tetap berjalan di bawahnya,
## jadi kaki tetap mengikuti kecepatan badan dan tidak meluncur saat menyerang.

const Catalog = preload("res://src/game/animation/catalog.gd")
const FADE_IN := 0.08
const FADE_OUT := 0.12

var animation_player: AnimationPlayer
var skeleton: Skeleton3D
var clip: Animation
var current_name := ""
var elapsed := 0.0
var playing := false
var tracks: Dictionary[int, int] = {}
var _sequence: Array[String] = []
var _spine := -1


func configure(source: AnimationPlayer, rig: Skeleton3D) -> void:
	animation_player = source
	skeleton = rig
	_spine = skeleton.find_bone("spine_01") if skeleton != null else -1
	active = false
	influence = 0.0


func play_sequence(names: Array[String]) -> float:
	if playing or animation_player == null or skeleton == null:
		return 0.0
	_sequence.clear()
	var total := 0.0
	for name in names:
		var runtime_name: String = Catalog.play_name(name)
		if not animation_player.has_animation(runtime_name):
			continue
		var candidate := animation_player.get_animation(runtime_name)
		if candidate == null or candidate.length <= 0.0:
			continue
		_sequence.append(name)
		total += candidate.length
	if _sequence.is_empty():
		return 0.0
	_play_next()
	return total


func cancel() -> void:
	_sequence.clear()
	clip = null
	current_name = ""
	playing = false
	tracks.clear()
	active = false
	influence = 0.0


func _play_next() -> void:
	if _sequence.is_empty():
		cancel()
		return
	current_name = _sequence.pop_front()
	var runtime_name: String = Catalog.play_name(current_name)
	clip = animation_player.get_animation(runtime_name)
	tracks = _upper_body_tracks(clip)
	elapsed = 0.0
	playing = true
	active = true
	influence = 0.0


func _upper_body_tracks(source: Animation) -> Dictionary[int, int]:
	var result: Dictionary[int, int] = {}
	if source == null or skeleton == null or _spine < 0:
		return result
	for track in range(source.get_track_count()):
		if source.track_get_type(track) != Animation.TYPE_ROTATION_3D:
			continue
		var path := source.track_get_path(track)
		if path.get_subname_count() != 1:
			continue
		var bone := skeleton.find_bone(path.get_subname(0))
		var ancestor := bone
		while ancestor >= 0 and ancestor != _spine:
			ancestor = skeleton.get_bone_parent(ancestor)
		if bone >= 0 and ancestor == _spine:
			result[track] = bone
	return result


func _physics_process(delta: float) -> void:
	if not playing or clip == null:
		return
	elapsed = minf(elapsed + delta, clip.length)
	influence = minf(smoothstep(0.0, FADE_IN, elapsed),
		smoothstep(0.0, FADE_OUT, clip.length - elapsed))
	if elapsed >= clip.length:
		_play_next()


func _process_modification_with_delta(_delta: float) -> void:
	if not playing or clip == null or skeleton == null:
		return
	for track: int in tracks:
		skeleton.set_bone_pose_rotation(tracks[track],
			clip.rotation_track_interpolate(track, elapsed))
