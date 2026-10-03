extends Node3D
## Satu teman kecil di padang: diam dengan pose berbeda dari pemain, lalu
## sesekali berjalan beberapa langkah di sekitar tempat ia pertama ditemui.

const Field = preload("res://src/game/world/field.gd")
const Character = preload("res://src/game/mannequin.gd")

const HEIGHT := 1.8
const WALK_SPEED := 0.85
const WANDER_RADIUS := 4.5
const IDLE_CLIPS: Array[String] = [
	"Idle_FoldArms_Loop",
	"Idle_Rail_Loop",
	"Idle_No_Loop",
]
const WALK_CLIP := "Walk_Formal_Loop"
const TALK_CLIP := "Idle_Talking_Loop"

var display_name := "Mira"
var field: Field
var player: CharacterBody3D
var home := Vector2.ZERO
var visual: Character
var walk_count := 0
var _rng := RandomNumberGenerator.new()
var _idle_time := 1.8
var _walk_target := Vector2.ZERO
var _walking := false
var _talking := false


func _ready() -> void:
	name = "Mira"
	_rng.seed = 42017
	if field != null:
		_set_ground_position(home)
	visual = Character.new()
	visual.name = "Visual"
	visual.position.y = -HEIGHT * 0.5
	visual.scale = Vector3.ONE * 0.92
	add_child(visual)
	_apply_npc_palette()
	visual.set_locomotion(IDLE_CLIPS[0], 1.0)


func _physics_process(delta: float) -> void:
	if field == null or visual == null:
		return
	if _talking:
		if player != null:
			_face_point(Vector2(player.global_position.x, player.global_position.z))
		return
	if _walking:
		_step_toward_target(delta)
		return
	_idle_time -= delta
	if _idle_time <= 0.0:
		_choose_next_action()


func start_conversation(player_position: Vector3) -> void:
	_talking = true
	_walking = false
	_idle_time = 3.0
	_face_point(Vector2(player_position.x, player_position.z))
	if visual != null:
		visual.set_locomotion(TALK_CLIP, 1.0)


func end_conversation() -> void:
	_talking = false
	_walking = false
	_idle_time = _rng.randf_range(2.5, 5.0)
	if visual != null:
		visual.set_locomotion(IDLE_CLIPS[0], 1.0)


func is_walking() -> bool:
	return _walking


func _choose_next_action() -> void:
	if _rng.randf() < 0.38:
		_begin_wander()
		return
	var index := _rng.randi_range(0, IDLE_CLIPS.size() - 1)
	visual.set_locomotion(IDLE_CLIPS[index], 1.0)
	_idle_time = _rng.randf_range(3.5, 7.0)


func _begin_wander() -> void:
	var angle := _rng.randf_range(0.0, TAU)
	var distance := _rng.randf_range(2.0, WANDER_RADIUS)
	var offset := Vector2(cos(angle), sin(angle)) * distance
	var target := home + offset
	if target.distance_to(home) > WANDER_RADIUS:
		target = home + offset.normalized() * WANDER_RADIUS
	_walk_target = Field.clamp_inside(target, 2.0)
	if _walk_target.distance_to(Vector2(global_position.x, global_position.z)) < 1.0:
		_walk_target = Field.clamp_inside(home + Vector2(2.0, 0.0), 2.0)
	_walking = true
	walk_count += 1
	visual.set_locomotion(WALK_CLIP, 1.0)


func _step_toward_target(delta: float) -> void:
	var here := Vector2(global_position.x, global_position.z)
	var offset := _walk_target - here
	if offset.length() < 0.22:
		_set_ground_position(_walk_target)
		_walking = false
		_idle_time = _rng.randf_range(3.5, 7.0)
		var index := _rng.randi_range(0, IDLE_CLIPS.size() - 1)
		visual.set_locomotion(IDLE_CLIPS[index], 1.0)
		return
	var step := offset.normalized() * minf(WALK_SPEED * delta, offset.length())
	_set_ground_position(here + step)
	_face_direction(step)


func _set_ground_position(point: Vector2) -> void:
	var ground := field.surface_height(point.x, point.y)
	global_position = Vector3(point.x, ground + HEIGHT * 0.5, point.y)


func _face_point(point: Vector2) -> void:
	_face_direction(point - Vector2(global_position.x, global_position.z))


func _face_direction(direction: Vector2) -> void:
	if visual == null or direction.length_squared() < 0.001:
		return
	var facing := atan2(-direction.x, -direction.y)
	visual.rotation.y = lerp_angle(visual.rotation.y, facing, 0.18)


func _apply_npc_palette() -> void:
	# Aksen amber memisahkan siluet Mira daripada kulit hitam pemain.
	if visual.skin == null:
		return
	var materials: Array[ShaderMaterial] = [visual.skin.skin]
	var inner := visual.get("_skin_material") as ShaderMaterial
	if inner != null:
		materials.append(inner)
	for material in materials:
		material.set_shader_parameter("skin_dark", Color("342426"))
		material.set_shader_parameter("skin_light", Color("a76831"))
