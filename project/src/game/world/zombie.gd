extends CharacterBody3D
## Zombie mannequin UAL: mengejar pemain, mencakar dari dekat, lalu tumbang kena sihir.

signal died(zombie: Node3D)

const Character = preload("res://src/game/mannequin.gd")
const Catalog = preload("res://src/game/animation/catalog.gd")
const Metrics = preload("res://src/game/animation/anim_metrics.gd")

const HEIGHT := 1.8
const RADIUS := 0.30
const WALK_SPEED := 0.978
const ATTACK_RANGE := 1.55
const ATTACK_INTERVAL := 2.35
const ATTACK_DAMAGE := 12
const START_HEALTH := 96
const STAGE_HEALTH_GAIN := 24
const DEATH_LIFETIME := 3.2

var player: CharacterBody3D
var field: Node3D
var visual: Character
var stage := 1
var max_health := START_HEALTH
var health := START_HEALTH
var dead := false
var _burn_left := 0.0
var _burn_tick_left := 0.0
var _burn_damage := 0
var _attack_cooldown := 0.8
var _death_left := 0.0


func set_stage_difficulty(stage_value: int) -> void:
	stage = maxi(1, stage_value)
	max_health = START_HEALTH + (stage - 1) * STAGE_HEALTH_GAIN
	health = max_health


func apply_burn(damage_per_tick: int, duration: float) -> void:
	if dead or damage_per_tick <= 0 or duration <= 0.0:
		return
	_burn_damage = maxi(_burn_damage, damage_per_tick)
	_burn_left = maxf(_burn_left, duration)
	_burn_tick_left = minf(_burn_tick_left, 0.38)


func _ready() -> void:
	name = "Zombie"
	collision_layer = 4
	collision_mask = 0
	floor_snap_length = 0.25
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	shape.shape = capsule
	add_child(shape)
	visual = Character.new()
	visual.measure_metrics = false
	visual.sword_layer_enabled = false
	visual.name = "Visual"
	visual.position.y = -HEIGHT * 0.5
	add_child(visual)
	var idle_name := "Zombie_Idle_Loop"
	var walk_name := "Zombie_Walk_Fwd_Loop"
	var idle_metrics := Metrics.measure(visual.animation, visual.skeleton,
		Catalog.play_name(idle_name), Metrics.IDLE_RATE)
	var walk_metrics := Metrics.measure(visual.animation, visual.skeleton,
		Catalog.play_name(walk_name), Metrics.SAMPLE_RATE)
	var baseline := float(idle_metrics["foot_min_y"])
	idle_metrics["ground_offset"] = Metrics.SOLE
	walk_metrics["ground_offset"] = clampf(
		baseline - float(walk_metrics["foot_min_y"]) + Metrics.SOLE,
		0.0, Metrics.MAX_OFFSET)
	visual.metrics[idle_name] = idle_metrics
	visual.metrics[walk_name] = walk_metrics
	_apply_zombie_palette()
	visual.set_locomotion("Zombie_Idle_Loop", 1.0)
	_update_ground_height()


func _physics_process(delta: float) -> void:
	if dead:
		_death_left = maxf(0.0, _death_left - delta)
		if _death_left <= 0.0:
			queue_free()
		return
	_update_burn(delta)
	if dead:
		return
	if player == null or visual == null:
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_update_ground_height()
	var offset := Vector2(
		player.global_position.x - global_position.x,
		player.global_position.z - global_position.z)
	var distance := offset.length()
	if visual.is_busy():
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if distance <= ATTACK_RANGE:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		visual.set_locomotion("Zombie_Idle_Loop", 1.0)
		if _attack_cooldown <= 0.0:
			_attack_cooldown = ATTACK_INTERVAL
			visual.play_action("Zombie_Scratch")
			if player.has_method("take_damage"):
				player.call("take_damage", ATTACK_DAMAGE)
		return
	if distance <= 0.01:
		return
	var direction := offset / distance
	velocity.x = direction.x * WALK_SPEED
	velocity.z = direction.y * WALK_SPEED
	move_and_slide()
	var facing := atan2(-direction.x, -direction.y)
	visual.rotation.y = lerp_angle(visual.rotation.y, facing, 1.0 - exp(-8.0 * delta))
	# Satu klip gait diukur per zombie; skala main disetel ke langkah aktual.
	var natural_speed := visual.natural_speed("Zombie_Walk_Fwd_Loop")
	visual.set_locomotion("Zombie_Walk_Fwd_Loop", WALK_SPEED / natural_speed)


func _update_burn(delta: float) -> void:
	if _burn_left <= 0.0:
		return
	_burn_left = maxf(0.0, _burn_left - delta)
	_burn_tick_left -= delta
	while _burn_tick_left <= 0.0 and _burn_left > 0.0 and not dead:
		_burn_tick_left += 0.46
		take_damage(_burn_damage)


func can_be_targeted() -> bool:
	return not dead and health > 0 and is_inside_tree()


func take_damage(amount: int) -> void:
	if dead or amount <= 0:
		return
	health = maxi(0, health - amount)
	if health > 0:
		visual.play_action("Hit_Chest")
		return
	dead = true
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = 0
	_death_left = DEATH_LIFETIME
	visual.play_action("Death01")
	died.emit(self)


func _update_ground_height() -> void:
	if field == null or not field.has_method("surface_height"):
		return
	global_position.y = float(field.call(
			"surface_height", global_position.x, global_position.z)) + HEIGHT * 0.5


func _apply_zombie_palette() -> void:
	if visual.skin == null:
		return
	var materials: Array[ShaderMaterial] = [visual.skin.skin]
	var inner := visual.get("_skin_material") as ShaderMaterial
	if inner != null:
		materials.append(inner)
	for material in materials:
		material.set_shader_parameter("skin_dark", Color("1d3025"))
		material.set_shader_parameter("skin_light", Color("5e9360"))
