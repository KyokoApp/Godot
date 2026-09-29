extends Node
## Two contacts per animation cycle; actual movement/floor gate prevents wall footsteps.

const Island = preload("res://src/game/island.gd")
const WorldAudio = preload("res://src/game/audio/world_audio.gd")
const Mannequin = preload("res://src/game/mannequin.gd")

var audio: WorldAudio
var island: Island
var body: CharacterBody3D
var visual: Mannequin
var emitted := 0
var _last_half := -1
var _last_clip := ""
var _air_time := 0.0
var _contact_cooldown := 0.0
var _left := false


func surface_at(point: Vector3, normal: Vector3) -> String:
	if normal.y < 0.78 or point.y > island.surface_height(point.x, point.z) + 0.5:
		return "stone"
	if point.y < 4.0:
		return "dirt"
	if absf(point.z) < 330 and Island.road_distance(point.x, point.z) < 11:
		return "dirt"
	return "grass"


func update_motion(delta: float, speed: float) -> void:
	_contact_cooldown = maxf(0, _contact_cooldown - delta)
	if not body.is_on_floor():
		_air_time += delta
		_last_half = -1
		return
	var landed := _air_time > 0.18
	_air_time = 0
	if speed < 0.15 and not landed:
		_last_half = -1
		return
	var animation := visual.animation
	var length := animation.current_animation_length
	if length <= 0:
		return
	var half := int(animation.current_animation_position / length * 2.0)
	var clip := animation.current_animation
	var contact := half != _last_half or clip != _last_clip
	_last_half = half
	_last_clip = clip
	if (contact or landed) and _contact_cooldown <= 0:
		var point := body.global_position - Vector3(0, 0.82, 0)
		_left = not _left
		point += visual.global_basis.x * (0.13 if _left else -0.13)
		audio.footstep(point, surface_at(point, body.get_floor_normal()), speed, landed)
		emitted += 1
		_contact_cooldown = 0.12
