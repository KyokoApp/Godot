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
const MELEE_RANGE := 2.35

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


func resolve_player_attack(clip: String) -> void:
	# Jeda kecil menempatkan hit di awal ayunan, bukan tepat saat tombol disentuh.
	var delay := 0.27 if clip != "Sword_Regular_C" else 0.34
	get_tree().create_timer(delay).timeout.connect(_resolve_melee_hit.bind(clip))


func _resolve_melee_hit(clip: String) -> void:
	if player == null or not is_instance_valid(player) or player.get("health") <= 0:
		return
	var visual := player.get("visual") as Node3D
	if visual == null:
		return
	var facing := -visual.global_transform.basis.z
	facing.y = 0.0
	if facing.length_squared() < 0.001:
		return
	facing = facing.normalized()
	var nearest: Zombie
	var nearest_distance := MELEE_RANGE
	for zombie in zombies:
		if not is_instance_valid(zombie) or zombie.dead:
			continue
		var to_zombie := Vector3(
			zombie.global_position.x - player.global_position.x,
			0.0,
			zombie.global_position.z - player.global_position.z)
		var distance := to_zombie.length()
		if distance > 0.01 and distance <= nearest_distance \
				and facing.dot(to_zombie / distance) >= -0.12:
			nearest = zombie
			nearest_distance = distance
	if nearest == null:
		return
	var damage := 40 if clip == "Sword_Regular_C" else 32
	var was_alive := not nearest.dead
	nearest.take_damage(damage)
	if was_alive and nearest.dead:
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
