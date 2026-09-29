extends Node3D
## Pet adalah node dunia terpisah dari rig. Attack diarahkan ke titik bidik kamera.

const Spirit = preload("res://src/game/legacy_spirit/spirit_visual.gd")
const Projectile = preload("res://src/game/fire_projectile.gd")
const Burst = preload("res://src/game/fire_burst.gd")
const COOLDOWN := 0.85
const MAX_PROJECTILES := 3
const MAX_BURSTS := 2

var player: Node3D
var facing: Node3D
var camera: Camera3D
var cooldown := 0.0
var projectiles: Array[CharacterBody3D] = []
var bursts: Array[Node3D] = []
var _body: Spirit
var _previous_player := Vector3.ZERO
var _time := 0.0


func _ready() -> void:
	_body = Spirit.new()
	add_child(_body)
	if player != null:
		global_position = _desired_position()
		_previous_player = player.global_position


func _desired_position() -> Vector3:
	var side := Vector3(1.12, 0, 0.12)
	if facing != null:
		side = facing.global_basis * side
	return player.global_position + side + Vector3(0, 0.55 + sin(_time * 2.4) * 0.09, 0)


func _physics_process(delta: float) -> void:
	_time += delta
	cooldown = maxf(0.0, cooldown - delta)
	if player == null:
		return
	var target := _desired_position()
	if global_position.distance_to(target) > 5:
		global_position = target
	else:
		global_position = global_position.lerp(target, 1.0 - exp(-9.0 * delta))
	# Tetap terpisah dari tubuh, termasuk saat pemain berputar mendadak.
	var offset := Vector2(global_position.x - player.global_position.x,
		global_position.z - player.global_position.z)
	if offset.length() < 0.85:
		var direction := offset.normalized() if offset.length() > 0.001 else Vector2.RIGHT
		global_position.x = player.global_position.x + direction.x * 0.85
		global_position.z = player.global_position.z + direction.y * 0.85
	_body.external_velocity = ((player.global_position - _previous_player)
		/ maxf(delta, 0.001)).limit_length(20.0)
	_previous_player = player.global_position


func attack() -> bool:
	_prune()
	if cooldown > 0.0 or projectiles.size() >= MAX_PROJECTILES or camera == null:
		return false
	cooldown = COOLDOWN
	_body.pulse()
	var screen := camera.get_viewport().get_visible_rect().size * Vector2(0.5, 0.42)
	var start := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var aim := start + direction * 35.0
	var query := PhysicsRayQueryParameters3D.create(start, aim, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		aim = hit["position"]
	var shot := Projectile.new()
	shot.position = global_position
	# Parent game berada pada origin dunia; set global sesudah add agar tetap aman.
	get_parent().add_child(shot)
	shot.global_position = global_position
	var duration := clampf(global_position.distance_to(aim) / 18.0, 0.25, 1.5)
	shot.velocity = (aim - shot.global_position) / duration - Projectile.GRAVITY * duration * 0.5
	shot.impacted.connect(_on_impact)
	projectiles.append(shot)
	return true


func _on_impact(point: Vector3, normal: Vector3) -> void:
	_prune()
	if bursts.size() >= MAX_BURSTS:
		bursts.pop_front().queue_free()
	var burst := Burst.new()
	burst.surface_normal = normal
	burst.position = (get_parent() as Node3D).to_local(point + normal * 0.02)
	get_parent().add_child(burst)
	bursts.append(burst)


func _prune() -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		if not is_instance_valid(projectiles[index]):
			projectiles.remove_at(index)
	for index in range(bursts.size() - 1, -1, -1):
		if not is_instance_valid(bursts[index]):
			bursts.remove_at(index)
