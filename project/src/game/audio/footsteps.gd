extends Node
## Dua kontak per siklus animasi; gerak nyata + lantai mencegah langkah palsu.

const Field = preload("res://src/game/world/field.gd")
const WorldAudio = preload("res://src/game/audio/world_audio.gd")
const Character = preload("res://src/game/mannequin.gd")
const EDGE_DIRT := 45.0

var audio: WorldAudio
var field: Field
var body: CharacterBody3D
var visual: Character
var emitted := 0
var _last_half := -1
var _last_clip := ""
var _air_time := 0.0
var _contact_cooldown := 0.0
var _left := false


func surface_at(point: Vector3, normal: Vector3) -> String:
	# Padang ini seluruhnya rumput; hanya cincin tanah di tepi pagar yang beda,
	# sama seperti warna tepi di ground.gdshader.
	if normal.y < 0.55:
		return "stone"
	if field != null and maxf(absf(point.x), absf(point.z)) > EDGE_DIRT:
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
