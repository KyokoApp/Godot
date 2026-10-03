extends Node3D
## Dunia Survival: tanah datar tak berbatas dan zombie yang terus mengejar pemain.

signal status_changed(elapsed_seconds: float, living_zombies: int, defeated: int)

const SurvivalField = preload("res://src/game/world/survival_field.gd")
const Zombie = preload("res://src/game/world/zombie.gd")

const MAX_ZOMBIES := 5
const FIRST_WAVE := 3
const SPAWN_INTERVAL := 3.2
const SPAWN_NEAR := 13.0
const SPAWN_FAR := 20.0
const MAGIC_LOCK_RANGE := 32.0

var player: CharacterBody3D
var ground: SurvivalField
var zombies: Array[Zombie] = []
var elapsed_seconds := 0.0
var defeated := 0
var _spawn_cooldown := 1.0
var _status_clock := 0.0
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	name = "SurvivalWorld"
	_random.randomize()
	ground = SurvivalField.new()
	ground.player = player
	add_child(ground)
	for _index in FIRST_WAVE:
		_spawn_zombie()
	_publish_status()


func _process(delta: float) -> void:
	if player == null:
		return
	elapsed_seconds += delta
	_spawn_cooldown = maxf(0.0, _spawn_cooldown - delta)
	_status_clock += delta
	_prune_zombies()
	if zombies.size() < MAX_ZOMBIES and _spawn_cooldown <= 0.0:
		_spawn_zombie()
		_spawn_cooldown = SPAWN_INTERVAL
	if _status_clock >= 0.5:
		_status_clock = 0.0
		_publish_status()


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
	var living := 0
	for zombie in zombies:
		if is_instance_valid(zombie) and not zombie.dead:
			living += 1
	status_changed.emit(elapsed_seconds, living, defeated)
