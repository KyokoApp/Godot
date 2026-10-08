extends CharacterBody3D
## Zombie mannequin UAL: mengejar pemain, mencakar dari dekat, lalu tumbang kena sihir.

signal died(zombie: Node3D)
signal health_changed(current: int, maximum: int)

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
const BOSS_NAMES: Array[String] = [
	"GOLIAT ABU", "RAJA KELAM", "PENGHANCUR SENJA", "TITAN BARA",
]

var player: CharacterBody3D
var field: Node3D
var visual: Character
var stage := 1
var max_health := START_HEALTH
var health := START_HEALTH
var is_boss := false
var boss_name := ""
var dead := false
var _arcane_mark_left := 0.0
var _arcane_mark_bonus := 0.0
var _burn_left := 0.0
var _burn_tick_left := 0.0
var _burn_damage := 0
var _slow_left := 0.0
var _slow_multiplier := 1.0
var _attack_cooldown := 0.8
var _death_left := 0.0


func set_stage_difficulty(stage_value: int, boss_value: bool = false) -> void:
	stage = maxi(1, stage_value)
	is_boss = boss_value
	if is_boss:
		var milestone := maxi(1, int(stage / 5))
		max_health = 900 + (milestone - 1) * 260
		boss_name = BOSS_NAMES[posmod(milestone - 1, BOSS_NAMES.size())]
	else:
		max_health = START_HEALTH + (stage - 1) * STAGE_HEALTH_GAIN
		boss_name = ""
	health = max_health


func apply_arcane_mark(damage_bonus: float, duration: float) -> void:
	if dead or damage_bonus <= 0.0 or duration <= 0.0:
		return
	_arcane_mark_bonus = maxf(_arcane_mark_bonus, clampf(damage_bonus, 0.0, 0.20))
	_arcane_mark_left = maxf(_arcane_mark_left, duration)


func apply_burn(damage_per_tick: int, duration: float) -> void:
	if dead or damage_per_tick <= 0 or duration <= 0.0:
		return
	_burn_damage = maxi(_burn_damage, damage_per_tick)
	_burn_left = maxf(_burn_left, duration)
	_burn_tick_left = minf(_burn_tick_left, 0.38)


func apply_slow(multiplier: float, duration: float) -> void:
	if dead or duration <= 0.0:
		return
	_slow_multiplier = minf(_slow_multiplier, clampf(multiplier, 0.35, 1.0))
	_slow_left = maxf(_slow_left, duration)


func _ready() -> void:
	name = "Zombie"
	collision_layer = 4
	collision_mask = 0
	floor_snap_length = 0.25
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.52 if is_boss else RADIUS
	capsule.height = 3.05 if is_boss else HEIGHT
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
	if is_boss:
		visual.scale = Vector3.ONE * 1.62
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
	_arcane_mark_left = maxf(0.0, _arcane_mark_left - delta)
	if _arcane_mark_left <= 0.0:
		_arcane_mark_bonus = 0.0
	_slow_left = maxf(0.0, _slow_left - delta)
	if _slow_left <= 0.0:
		_slow_multiplier = 1.0
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
	var attack_range := ATTACK_RANGE * (1.35 if is_boss else 1.0)
	if distance <= attack_range:
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
	var current_speed := WALK_SPEED * _slow_multiplier
	velocity.x = direction.x * current_speed
	velocity.z = direction.y * current_speed
	move_and_slide()
	var facing := atan2(-direction.x, -direction.y)
	visual.rotation.y = lerp_angle(visual.rotation.y, facing, 1.0 - exp(-8.0 * delta))
	# Satu klip gait diukur per zombie; skala main disetel ke langkah aktual.
	var natural_speed := visual.natural_speed("Zombie_Walk_Fwd_Loop")
	visual.set_locomotion("Zombie_Walk_Fwd_Loop", current_speed / natural_speed)


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
	var applied := amount
	if _arcane_mark_left > 0.0 and _arcane_mark_bonus > 0.0:
		applied = maxi(1, roundi(float(amount) * (1.0 + _arcane_mark_bonus)))
	health = maxi(0, health - applied)
	health_changed.emit(health, max_health)
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
	var dark := Color("1d3025")
	var light := Color("5e9360")
	if is_boss:
		var palettes: Array[Dictionary] = [
			{"dark": Color("281737"), "light": Color("b46bdd")},
			{"dark": Color("321a25"), "light": Color("dd6b87")},
			{"dark": Color("1a2639"), "light": Color("68b6db")},
			{"dark": Color("382515"), "light": Color("dfaa45")},
		]
		var palette: Dictionary = palettes[posmod(int(stage / 5) - 1, palettes.size())]
		dark = palette["dark"]
		light = palette["light"]
	var materials: Array[ShaderMaterial] = [visual.skin.skin]
	var inner := visual.get("_skin_material") as ShaderMaterial
	if inner != null:
		materials.append(inner)
	for material in materials:
		material.set_shader_parameter("skin_dark", dark)
		material.set_shader_parameter("skin_light", light)
