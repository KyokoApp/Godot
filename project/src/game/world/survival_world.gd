extends Node3D
## Dunia Survival: arena tanpa batas, stage satu menit, dan zombie makin ramai.

signal status_changed(status_text: String)

const SurvivalField = preload("res://src/game/world/survival_field.gd")
const Zombie = preload("res://src/game/world/zombie.gd")

const FIRST_WAVE := 3
const STAGE_DURATION := 60.0
const SPAWN_INTERVAL := 3.2
const SPAWN_NEAR := 13.0
const SPAWN_FAR := 20.0
const MAGIC_LOCK_RANGE := 32.0
const BASE_MAX_LIVING := 5
const MAX_LIVING_ZOMBIES := 18
const EXTRA_LIVING_PER_STAGE := 2
const RETURN_DELAY := 0.9

var player: CharacterBody3D
var ground: SurvivalField
var zombies: Array[Zombie] = []
var stage := 1
var stage_time_left := STAGE_DURATION
var elapsed_seconds := 0.0
var defeated := 0
var last_spawn_wave_size := 0
var _stage_elapsed := 0.0
var _spawn_cooldown := 1.0
var _status_clock := 0.0
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	name = "SurvivalWorld"
	_random.randomize()
	ground = SurvivalField.new()
	ground.player = player
	add_child(ground)
	last_spawn_wave_size = _spawn_wave(FIRST_WAVE)
	_publish_status()


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	elapsed_seconds += delta
	_stage_elapsed += delta
	var stage_advanced := false
	while _stage_elapsed >= STAGE_DURATION:
		_stage_elapsed -= STAGE_DURATION
		stage += 1
		stage_advanced = true
	stage_time_left = maxf(0.0, STAGE_DURATION - _stage_elapsed)
	_spawn_cooldown = maxf(0.0, _spawn_cooldown - delta)
	_status_clock += delta
	_prune_zombies()
	if stage_advanced:
		_spawn_cooldown = 0.0
	var living := living_zombie_count()
	if living < maximum_living_zombies() and _spawn_cooldown <= 0.0:
		last_spawn_wave_size = _spawn_wave(stage)
		_spawn_cooldown = SPAWN_INTERVAL
	if _status_clock >= 0.25 or stage_advanced:
		_status_clock = 0.0
		_publish_status()


static func format_status(stage_number: int, seconds_left: float,
		living: int, defeated_count: int) -> String:
	var timer_seconds := maxi(0, ceili(seconds_left))
	var minutes := int(timer_seconds / 60)
	var seconds := timer_seconds % 60
	return "STAGE %02d · %02d:%02d · ZOMBI %02d · KALAH %d" % [
		stage_number, minutes, seconds, living, defeated_count]


func maximum_living_zombies() -> int:
	return mini(MAX_LIVING_ZOMBIES, BASE_MAX_LIVING + (stage - 1) * EXTRA_LIVING_PER_STAGE)


func living_zombie_count() -> int:
	var living := 0
	for zombie in zombies:
		if is_instance_valid(zombie) and zombie.can_be_targeted():
			living += 1
	return living


func acquire_magic_target(from_position: Vector3) -> Zombie:
	var nearest: Zombie
	var nearest_distance_squared := MAGIC_LOCK_RANGE * MAGIC_LOCK_RANGE
	for zombie in zombies:
		if not is_instance_valid(zombie) or not zombie.can_be_targeted():
			continue
		var distance_squared := from_position.distance_squared_to(zombie.global_position)
		if distance_squared <= nearest_distance_squared:
			nearest = zombie
			nearest_distance_squared = distance_squared
	return nearest


func _spawn_wave(requested_count: int) -> int:
	var room := maxi(0, maximum_living_zombies() - living_zombie_count())
	var count := mini(requested_count, room)
	var spawned := 0
	for _index in count:
		_spawn_zombie()
		spawned += 1
	return spawned


func _on_zombie_died() -> void:
	defeated += 1
	_publish_status()


func _spawn_zombie() -> void:
	if player == null or ground == null:
		return
	var angle := _random.randf_range(0.0, TAU)
	var distance := _random.randf_range(SPAWN_NEAR, SPAWN_FAR)
	var point := Vector3(
		player.global_position.x + cos(angle) * distance,
		Zombie.HEIGHT * 0.5,
		player.global_position.z + sin(angle) * distance)
	var zombie := Zombie.new()
	zombie.player = player
	zombie.field = ground
	zombie.died.connect(_on_zombie_died)
	add_child(zombie)
	zombie.global_position = point
	zombies.append(zombie)


func _prune_zombies() -> void:
	for index in range(zombies.size() - 1, -1, -1):
		if not is_instance_valid(zombies[index]):
			zombies.remove_at(index)


func _publish_status() -> void:
	status_changed.emit(format_status(stage, stage_time_left, living_zombie_count(), defeated))
