extends Node3D
## Pet terpisah dari rig; tembakan yang sama bisa dikunci ke target Survival.

signal cast_started
signal impact_landed(target: Node3D, damage: int, critical: bool)

const CastLayer = preload("res://src/game/animation/cast_layer.gd")
const Spirit = preload("res://src/game/legacy_spirit/spirit_visual.gd")
const Projectile = preload("res://src/game/fire_projectile.gd")
const Burst = preload("res://src/game/fire_burst.gd")
const COOLDOWN := 0.85
const AUTO_FIRE_INTERVAL := 0.18
const RAPID_FIRE_COOLDOWN := 0.14
const MAGIC_DAMAGE := 48
const MAX_PROJECTILES := 3
const RAPID_FIRE_MAX_PROJECTILES := 16
const MAX_BURSTS := 2

var player: Node3D
var facing: Node3D
var camera: Camera3D
var cooldown := 0.0
var cooldown_duration := COOLDOWN
var projectile_limit := MAX_PROJECTILES
var damage_multiplier := 1.0
var cooldown_multiplier := 1.0
var critical_chance := 0.0
var critical_multiplier := 2.0
var extra_shot_chance := 0.0
var homing_turn_rate_multiplier := 1.0
var rapid_fire_enabled := false
var casting := false
var shots_fired := 0
var projectiles: Array[CharacterBody3D] = []
var bursts: Array[Node3D] = []
var _windup := 0.0
var _locked_target: Node3D
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
	if casting:
		_windup -= delta
		if _windup <= 0:
			casting = false
			_release_shot()


func set_rapid_fire(enabled: bool) -> void:
	rapid_fire_enabled = enabled
	var base_cooldown := RAPID_FIRE_COOLDOWN if enabled else COOLDOWN
	cooldown_duration = base_cooldown * cooldown_multiplier
	projectile_limit = RAPID_FIRE_MAX_PROJECTILES if enabled else MAX_PROJECTILES


func set_survival_modifiers(modifiers: Dictionary) -> void:
	damage_multiplier = float(modifiers.get("damage_multiplier", 1.0))
	cooldown_multiplier = float(modifiers.get("cooldown_multiplier", 1.0))
	critical_chance = clampf(float(modifiers.get("critical_chance", 0.0)), 0.0, 0.75)
	critical_multiplier = maxf(1.25, float(modifiers.get("critical_multiplier", 2.0)))
	extra_shot_chance = clampf(float(modifiers.get("extra_shot_chance", 0.0)), 0.0, 0.75)
	homing_turn_rate_multiplier = maxf(1.0, float(modifiers.get("homing_turn_rate_multiplier", 1.0)))
	set_rapid_fire(rapid_fire_enabled)


func reset_survival_modifiers() -> void:
	set_survival_modifiers({})
	set_rapid_fire(false)


func attack(lock_target: Node3D = null) -> bool:
	_prune()
	if casting or cooldown > 0.0 or projectiles.size() >= projectile_limit or camera == null:
		return false
	_locked_target = lock_target if is_instance_valid(lock_target) else null
	cooldown = cooldown_duration
	casting = true
	_windup = CastLayer.RELEASE_TIME
	cast_started.emit()
	return true


func _release_shot() -> void:
	if not is_instance_valid(camera):
		_locked_target = null
		return
	_body.pulse()
	var lock_target := _locked_target
	_locked_target = null
	var has_target := is_instance_valid(lock_target)
	if has_target and lock_target.has_method("can_be_targeted"):
		has_target = bool(lock_target.call("can_be_targeted"))
	var aim: Vector3
	if has_target:
		aim = lock_target.global_position + Projectile.HOMING_AIM_OFFSET
	else:
		var screen := camera.get_viewport().get_visible_rect().size * Vector2(0.5, 0.42)
		var start := camera.project_ray_origin(screen)
		var direction := camera.project_ray_normal(screen)
		aim = start + direction * 35.0
		var query := PhysicsRayQueryParameters3D.create(start, aim, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			aim = hit["position"]
	var projectile_count := 1
	if randf() < extra_shot_chance:
		projectile_count = 2
	for shot_index in projectile_count:
		_spawn_projectile(lock_target, has_target, aim, shot_index, projectile_count)


func _spawn_projectile(lock_target: Node3D, has_target: bool, aim: Vector3,
		shot_index: int, projectile_count: int) -> void:
	var shot := Projectile.new()
	shot.homing_target = lock_target if has_target else null
	shot.homing_speed = Projectile.HOMING_SPEED * homing_turn_rate_multiplier
	shot.homing_turn_rate = Projectile.HOMING_TURN_RATE * homing_turn_rate_multiplier
	get_parent().add_child(shot)
	shot.global_position = global_position
	if has_target:
		var spread := camera.global_basis.x \
			* (float(shot_index) - float(projectile_count - 1) * 0.5) * 0.24
		shot.velocity = (aim + spread - shot.global_position).normalized() * shot.homing_speed
	else:
		var duration := clampf(global_position.distance_to(aim) / 18.0, 0.25, 1.5)
		shot.velocity = (aim - shot.global_position) / duration - Projectile.GRAVITY * duration * 0.5
	shot.impacted.connect(_on_impact.bind(shot))
	projectiles.append(shot)
	shots_fired += 1
	var audio := get_tree().get_first_node_in_group("world_audio")
	if audio != null:
		audio.shoot(global_position)
		audio.follow_fire(shot, true)


func _on_impact(point: Vector3, normal: Vector3,
		projectile: CharacterBody3D = null) -> void:
	if projectile != null:
		var collider := projectile.get("impact_collider") as Node
		if collider != null and collider.has_method("take_damage"):
			var critical := randf() < critical_chance
			var damage := maxi(1, roundi(MAGIC_DAMAGE * damage_multiplier))
			if critical:
				damage = maxi(1, roundi(damage * critical_multiplier))
			collider.call("take_damage", damage)
			if collider is Node3D:
				impact_landed.emit(collider as Node3D, damage, critical)
	_prune()
	if bursts.size() >= MAX_BURSTS:
		bursts.pop_front().queue_free()
	var burst := Burst.new()
	burst.surface_normal = normal
	burst.position = (get_parent() as Node3D).to_local(point + normal * 0.02)
	get_parent().add_child(burst)
	bursts.append(burst)
	var audio := get_tree().get_first_node_in_group("world_audio")
	if audio != null:
		audio.explode(point + normal * 0.15)


func _prune() -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		if not is_instance_valid(projectiles[index]):
			projectiles.remove_at(index)
	for index in range(bursts.size() - 1, -1, -1):
		if not is_instance_valid(bursts[index]):
			bursts.remove_at(index)
