extends Node3D
## Dunia Survival tanpa batas: zombie beruntun, stage makin padat dan makin tangguh.

signal status_changed(status_text: String)
signal progression_changed(progress: Dictionary)
signal buff_choice_requested(choices: Array, level: int)
signal level_up(level: int)

const SurvivalField = preload("res://src/game/world/survival_field.gd")
const Zombie = preload("res://src/game/world/zombie.gd")
const BuffSystem = preload("res://src/game/survival/buff_system.gd")

const FIRST_WAVE := 3
const STAGE_DURATION := 60.0
const SPAWN_INTERVAL := 3.2
const MIN_SPAWN_INTERVAL := 0.82
const SPAWN_NEAR := 13.0
const SPAWN_FAR := 20.0
const MAGIC_LOCK_RANGE := 32.0
const BASE_MAX_LIVING := 9
const MAX_LIVING_ZOMBIES := 36
const EXTRA_LIVING_PER_STAGE := 3
const RETURN_DELAY := 0.9
const BASE_KILL_EXPERIENCE := 24

var player: CharacterBody3D
var fire_pet: Node3D
var ground: SurvivalField
var buff_system: SurvivalBuffSystem
var zombies: Array[Zombie] = []
var stage := 1
var stage_time_left := STAGE_DURATION
var elapsed_seconds := 0.0
var defeated := 0
var run_level := 1
var experience := 0
var last_xp_awarded := 0
var last_spawn_wave_size := 0
var _stage_elapsed := 0.0
var _spawn_cooldown := 1.0
var _status_clock := 0.0
var _pending_buff_choices := 0
var _awaiting_buff_choice := false
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	name = "SurvivalWorld"
	_random.randomize()
	ground = SurvivalField.new()
	ground.player = player
	add_child(ground)
	buff_system = BuffSystem.new()
	buff_system.player = player
	buff_system.fire_pet = fire_pet
	buff_system.world = self
	add_child(buff_system)
	last_spawn_wave_size = _spawn_wave(FIRST_WAVE)
	_publish_status()
	publish_progress()


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
		_spawn_cooldown = spawn_interval_for_stage()
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


func spawn_interval_for_stage() -> float:
	return maxf(MIN_SPAWN_INTERVAL, SPAWN_INTERVAL / (1.0 + 0.12 * (stage - 1)))


func living_zombie_count() -> int:
	var living := 0
	for zombie in zombies:
		if is_instance_valid(zombie) and zombie.can_be_targeted():
			living += 1
	return living


func acquire_magic_target(from_position: Vector3, range_bonus: float = 0.0) -> Zombie:
	var nearest: Zombie
	var lock_range := MAGIC_LOCK_RANGE + maxf(0.0, range_bonus)
	var nearest_distance_squared := lock_range * lock_range
	for zombie in zombies:
		if not is_instance_valid(zombie) or not zombie.can_be_targeted():
			continue
		var distance_squared := from_position.distance_squared_to(zombie.global_position)
		if distance_squared <= nearest_distance_squared:
			nearest = zombie
			nearest_distance_squared = distance_squared
	return nearest


func publish_progress(xp_awarded: int = 0, levels_gained: int = 0) -> void:
	var xp_to_next := 80
	if is_instance_valid(buff_system):
		xp_to_next = buff_system.experience_required(run_level)
	var health := 0
	var max_health := 100
	var shield := 0
	var shield_capacity := 0
	if is_instance_valid(player):
		health = int(player.get("health"))
		max_health = int(player.get("max_health"))
		shield = int(player.get("shield_points"))
		shield_capacity = int(player.get("shield_capacity"))
	progression_changed.emit({
		"level": run_level,
		"xp": experience,
		"xp_to_next": xp_to_next,
		"xp_awarded": xp_awarded,
		"levels_gained": levels_gained,
		"kills": defeated,
		"health": health,
		"max_health": max_health,
		"shield": shield,
		"shield_capacity": shield_capacity,
		"stage": stage,
	})


func choose_buff(buff_id: String) -> void:
	if not _awaiting_buff_choice or not is_instance_valid(buff_system):
		return
	if not buff_system.apply_buff(buff_id):
		_awaiting_buff_choice = false
		_request_buff_choice()
		return
	_awaiting_buff_choice = false
	_pending_buff_choices = maxi(0, _pending_buff_choices - 1)
	publish_progress()
	if _pending_buff_choices > 0:
		call_deferred("_request_buff_choice")


func clear_run() -> void:
	if is_instance_valid(buff_system):
		buff_system.clear_run()
	_pending_buff_choices = 0
	_awaiting_buff_choice = false
	run_level = 1
	experience = 0
	last_xp_awarded = 0


func _spawn_wave(requested_count: int) -> int:
	var room := maxi(0, maximum_living_zombies() - living_zombie_count())
	var count := mini(requested_count, room)
	var spawned := 0
	for _index in count:
		_spawn_zombie()
		spawned += 1
	return spawned


func _on_zombie_died(zombie: Node3D) -> void:
	defeated += 1
	if is_instance_valid(buff_system):
		buff_system.on_zombie_killed(zombie)
	var base_reward := BASE_KILL_EXPERIENCE + maxi(0, stage - 1) * 2
	var multiplier := float(buff_system.xp_multiplier) if is_instance_valid(buff_system) else 1.0
	last_xp_awarded = maxi(1, roundi(base_reward * multiplier))
	experience += last_xp_awarded
	var levels_gained := 0
	while experience >= _experience_required(run_level):
		experience -= _experience_required(run_level)
		run_level += 1
		levels_gained += 1
		level_up.emit(run_level)
		if run_level % 5 == 0:
			_pending_buff_choices += 1
	publish_progress(last_xp_awarded, levels_gained)
	_publish_status()
	if _pending_buff_choices > 0 and not _awaiting_buff_choice:
		_request_buff_choice()


func _experience_required(level: int) -> int:
	if is_instance_valid(buff_system):
		return buff_system.experience_required(level)
	return 80 + maxi(0, level - 1) * 18


func _request_buff_choice() -> void:
	if _pending_buff_choices <= 0 or _awaiting_buff_choice or not is_instance_valid(buff_system):
		return
	var choices := buff_system.available_choices(3)
	if choices.is_empty():
		return
	_awaiting_buff_choice = true
	buff_choice_requested.emit(choices, run_level)


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
	zombie.set_stage_difficulty(stage)
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
