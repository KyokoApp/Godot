class_name SurvivalBuffSystem
extends Node3D
## Mengurus stack buff, statistik run, serta visual sihir bertumpu pada karakter.

signal buffs_changed(stacks: Dictionary)

const Catalog = preload("res://src/game/survival/buff_catalog.gd")
const FX = preload("res://src/game/attack_fx/fx_resources.gd")
const SkillWave = preload("res://src/game/survival/skill_wave.gd")
const AEGIS_SHADER = preload("res://src/game/survival/aegis_shell.gdshader")

const XP_BASE := 80
const XP_GROWTH := 18
const ORBIT_LIMIT := 4
const MAX_SKILL_WAVES := 3

var player: Node3D
var fire_pet: Node3D
var world: Node3D
var meta_progress: Object
var stacks: Dictionary = {}
var magic_lock_range_bonus := 0.0
var xp_multiplier := 1.0

var _aegis_mesh: MeshInstance3D
var _aegis_material: ShaderMaterial
var _aegis_light: OmniLight3D
var _orbit_nodes: Array[Node3D] = []
var _orbit_clock := 0.0
var _orbit_damage_clock := 0.0
var _firestorm_clock := 0.0
var _ember_pulse_hits := 0
var _shield_flash := 0.0
var _regen_clock := 0.0
var _nova_active := false
var _nova_damage := 0
var _nova_radius := 0.0
var _burn_stacks := 0
var _skill_waves: Array[Node3D] = []


func _ready() -> void:
	name = "SurvivalBuffSystem"
	if player != null and player.has_signal("survival_stats_changed"):
		player.connect("survival_stats_changed", _on_player_stats_changed)
	if fire_pet != null and fire_pet.has_signal("impact_landed"):
		fire_pet.connect("impact_landed", _on_magic_impact)
	_apply_modifiers("")
	var starting_shield := int(_meta_modifiers().get("shield_capacity_bonus", 0))
	if starting_shield > 0 and is_instance_valid(player):
		player.call("grant_shield", starting_shield)


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	global_position = player.global_position
	var regen_stacks := get_stacks("soul_spring")
	if regen_stacks > 0 and int(player.get("health")) < int(player.get("max_health")):
		_regen_clock += delta * regen_stacks
		while _regen_clock >= 1.0:
			_regen_clock -= 1.0
			player.call("heal", 1)
			if int(player.get("health")) >= int(player.get("max_health")):
				_regen_clock = 0.0
				break
	else:
		_regen_clock = 0.0
	var firestorm := get_stacks("firestorm_aura")
	if firestorm > 0:
		_firestorm_clock += delta
		var firestorm_interval := maxf(2.8, 5.2 - 0.55 * firestorm)
		if _firestorm_clock >= firestorm_interval:
			_firestorm_clock = 0.0
			var storm_position := player.global_position
			storm_position.y = 0.0
			_spawn_skill_wave(storm_position, 4.4 + 0.35 * firestorm,
				Color("#ff765e"), 0.55)
			_damage_area_targets(storm_position, 4.4 + 0.35 * firestorm,
				12 + 6 * firestorm)
	else:
		_firestorm_clock = 0.0
	_orbit_clock += delta
	_orbit_damage_clock += delta
	if _aegis_mesh != null:
		var pulse := 1.0 + sin(_orbit_clock * 2.2) * 0.025
		_aegis_mesh.scale = Vector3(1.08 * pulse, 1.0 * pulse, 1.08 * pulse)
		_shield_flash = maxf(0.0, _shield_flash - delta * 2.6)
		_aegis_material.set_shader_parameter("hit_flash", _shield_flash)
	if not _orbit_nodes.is_empty():
		_update_orbit_positions()
		if _orbit_damage_clock >= 0.52:
			_orbit_damage_clock = 0.0
			_damage_nearby_zombies()


func get_stacks(buff_id: String) -> int:
	return int(stacks.get(buff_id, 0))


func experience_required(level: int) -> int:
	return XP_BASE + maxi(0, level - 1) * XP_GROWTH


func available_choices(count: int = 3) -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for card in Catalog.all_cards():
		var current := get_stacks(str(card.get("id", "")))
		var maximum := int(card.get("max_stacks", 1))
		if maximum > 0 and current >= maximum:
			continue
		card["stack_count"] = current
		available.append(card)
	available.shuffle()
	if available.size() > count:
		available.resize(count)
	return available


func apply_buff(buff_id: String) -> bool:
	var card := Catalog.card_for(buff_id)
	if card.is_empty():
		return false
	var current := get_stacks(buff_id)
	var maximum := int(card.get("max_stacks", 1))
	if maximum > 0 and current >= maximum:
		return false
	stacks[buff_id] = current + 1
	_apply_modifiers(buff_id)
	buffs_changed.emit(stacks.duplicate(true))
	return true


func set_orbit_stacks(count: int) -> void:
	var desired := 0
	if count > 0:
		desired = mini(ORBIT_LIMIT, 1 + count)
	while _orbit_nodes.size() < desired:
		_add_orbit_flame(_orbit_nodes.size())
	while _orbit_nodes.size() > desired:
		var orb: Node3D = _orbit_nodes.pop_back() as Node3D
		if is_instance_valid(orb):
			orb.queue_free()
	if count > 0:
		_ensure_aegis_light()
		_update_orbit_positions()


func on_zombie_killed(zombie: Node3D) -> void:
	var siphon := get_stacks("soul_siphon")
	if siphon > 0 and is_instance_valid(player):
		player.call("heal", 8 * siphon)
	var ward := get_stacks("soul_ward")
	if ward > 0 and is_instance_valid(player) and player.has_method("grant_shield"):
		player.call("grant_shield", 5 * ward)
	var kill_haste := get_stacks("kill_haste")
	if kill_haste > 0 and is_instance_valid(fire_pet):
		var remaining := float(fire_pet.get("cooldown"))
		fire_pet.set("cooldown", maxf(0.0, remaining - 0.08 * kill_haste))
	var persistent_heal := int(_meta_modifiers().get("heal_on_kill", 0))
	if persistent_heal > 0 and is_instance_valid(player):
		player.call("heal", persistent_heal)
	var nova := get_stacks("volatile_nova")
	if nova <= 0 or _nova_active or not is_instance_valid(zombie):
		return
	_nova_active = true
	_nova_damage = 30 + 22 * (nova - 1)
	_nova_radius = 3.4 + 0.3 * nova
	_spawn_nova(zombie.global_position)
	_nova_active = false


func clear_run() -> void:
	stacks.clear()
	if is_instance_valid(fire_pet):
		fire_pet.call("reset_survival_modifiers")
	if is_instance_valid(player):
		player.call("clear_survival_bonuses")
	magic_lock_range_bonus = 0.0
	xp_multiplier = 1.0
	_nova_active = false
	_regen_clock = 0.0
	_firestorm_clock = 0.0
	_ember_pulse_hits = 0
	_burn_stacks = 0
	for wave in _skill_waves:
		if is_instance_valid(wave):
			wave.queue_free()
	_skill_waves.clear()
	for orb in _orbit_nodes:
		if is_instance_valid(orb):
			orb.queue_free()
	_orbit_nodes.clear()
	if is_instance_valid(_aegis_mesh):
		_aegis_mesh.queue_free()
		_aegis_mesh = null
		_aegis_material = null
	if is_instance_valid(_aegis_light):
		_aegis_light.queue_free()
		_aegis_light = null


func _apply_modifiers(last_buff_id: String) -> void:
	var meta := _meta_modifiers()
	var ember := get_stacks("ember_core") + get_stacks("ascendant_sigil") * 0.17
	var rapid := get_stacks("rapid_cast")
	var aegis := get_stacks("arcane_aegis")
	var overcharge := get_stacks("overcharge")
	var volley := get_stacks("echo_volley")
	var seeker := get_stacks("seeking_flame")
	var vitality := get_stacks("vitality")
	var harvest := get_stacks("harvest")
	var focus := get_stacks("arcane_focus")
	var prism := get_stacks("prismatic_echo")
	var ward := get_stacks("soul_ward")
	var shield_refill := 0
	if last_buff_id == "arcane_aegis":
		shield_refill = 70
	elif last_buff_id == "soul_ward":
		shield_refill = 20
	if is_instance_valid(player):
		player.call("set_survival_bonuses",
			vitality * 25 + int(meta.get("health_bonus", 0)),
			aegis * 70 + ward * 20 + int(meta.get("shield_capacity_bonus", 0)),
			shield_refill,
			aegis * 0.07 + ward * 0.015 + float(meta.get("damage_reduction", 0.0)),
			float(meta.get("movement_speed_multiplier", 1.0)))
	if is_instance_valid(fire_pet):
		var run_cooldown := maxf(0.54, 1.0 - 0.10 * rapid)
		fire_pet.call("set_survival_modifiers", {
			"damage_multiplier": (1.0 + 0.18 * ember + 0.08 * focus)
				* float(meta.get("damage_multiplier", 1.0)),
			"cooldown_multiplier": maxf(0.54,
				run_cooldown * float(meta.get("cooldown_multiplier", 1.0))),
			"critical_chance": overcharge * 0.08 + float(meta.get("critical_chance", 0.0)),
			"critical_multiplier": 2.0 + 0.12 * overcharge
				+ float(meta.get("critical_multiplier_bonus", 0.0)),
			"extra_shot_chance": volley * 0.12 + prism * 0.08,
			"homing_turn_rate_multiplier": 1.0 + seeker * 0.18,
			"single_target_multiplier": 1.0 + 0.08 * get_stacks("soul_lance"),
			"projectile_speed_multiplier": float(meta.get("projectile_speed_multiplier", 1.0)),
		})
	magic_lock_range_bonus = get_stacks("long_reach") * 7.0 \
		+ float(meta.get("magic_lock_range_bonus", 0.0))
	xp_multiplier = (1.0 + 0.20 * harvest) * float(meta.get("xp_multiplier", 1.0))
	_nova_damage = 30 + 22 * (get_stacks("volatile_nova") - 1)
	_nova_radius = 3.4 + 0.3 * get_stacks("volatile_nova")
	_burn_stacks = get_stacks("burning_brand") + get_stacks("wildfire")
	set_orbit_stacks(get_stacks("cinder_orbit"))
	_refresh_aegis()


func _meta_modifiers() -> Dictionary:
	if meta_progress == null or not is_instance_valid(meta_progress):
		return {}
	return meta_progress.call("get_modifiers")


func _on_player_stats_changed() -> void:
	if _aegis_material != null:
		_shield_flash = 1.0


func _on_magic_impact(target: Node3D, damage: int, critical: bool) -> void:
	if not is_instance_valid(target):
		return
	var vampiric := get_stacks("vampiric_flame")
	if vampiric > 0 and is_instance_valid(player):
		player.call("heal", maxi(1, roundi(damage * 0.03 * vampiric)))
	var live_target := target.has_method("can_be_targeted") \
		and bool(target.call("can_be_targeted"))
	if live_target:
		var hunter_brand := get_stacks("hunter_brand")
		if hunter_brand > 0 and target.has_method("apply_arcane_mark"):
			target.call("apply_arcane_mark", 0.035 * hunter_brand, 3.2)
		var pulse_stacks := get_stacks("cinder_pulse")
		if pulse_stacks > 0:
			_ember_pulse_hits += 1
			var pulse_interval := maxi(3, 6 - pulse_stacks)
			if _ember_pulse_hits >= pulse_interval:
				_ember_pulse_hits = 0
				var pulse_radius := 2.5 + 0.18 * pulse_stacks
				_spawn_skill_wave(target.global_position, pulse_radius,
					Color("#ff9b67"), 0.46)
				_damage_area_targets(target.global_position, pulse_radius,
					12 + 5 * pulse_stacks, target)
		var brand := get_stacks("burning_brand")
		var wildfire := get_stacks("wildfire")
		var total_burn := brand + wildfire
		if total_burn > 0 and target.has_method("apply_burn"):
			var burn_damage := 5 + maxi(0, brand - 1) * 3 + wildfire * 2
			target.call("apply_burn", burn_damage, 2.5 + wildfire * 0.35)
		var frost := get_stacks("frost_rune")
		if frost > 0 and target.has_method("apply_slow"):
			var slow_multiplier := maxf(0.35, 1.0 - frost * 0.16)
			target.call("apply_slow", slow_multiplier, 1.6 + frost * 0.3)
		var executioner := get_stacks("executioner")
		var maximum_health := maxi(1, int(target.get("max_health")))
		var remaining_health := int(target.get("health"))
		if executioner > 0 and remaining_health > 0 \
				and float(remaining_health) / float(maximum_health) <= 0.35:
			target.call("take_damage", maxi(1, roundi(damage * 0.12 * executioner)))
	var chain_stacks := get_stacks("storm_chain")
	if chain_stacks > 0:
		_chain_lightning(target, chain_stacks)
	var bloom := get_stacks("critical_bloom")
	if critical and bloom > 0 and not _nova_active:
		_nova_active = true
		var radius := 2.2 + 0.22 * bloom
		var splash_damage := 14 + 10 * bloom
		_spawn_skill_wave(target.global_position, radius, Color("#ff9b67"), 0.46)
		_damage_area_targets(target.global_position, radius, splash_damage, target)
		_nova_active = false


func _chain_lightning(origin: Node3D, stacks_value: int) -> void:
	if world == null or not is_instance_valid(world) or stacks_value <= 0:
		return
	var remaining_targets: Array[Node3D] = []
	for zombie_value in world.get("zombies"):
		var zombie := zombie_value as Node3D
		if not is_instance_valid(zombie) or zombie == origin \
				or not zombie.has_method("can_be_targeted") \
				or not bool(zombie.call("can_be_targeted")):
			continue
		remaining_targets.append(zombie)
	var radius := 3.2 + stacks_value * 0.55
	for _chain in mini(stacks_value, remaining_targets.size()):
		var nearest: Node3D
		var nearest_distance := radius * radius
		for zombie in remaining_targets:
			var offset := zombie.global_position - origin.global_position
			offset.y = 0.0
			var distance_squared := offset.length_squared()
			if distance_squared < nearest_distance:
				nearest = zombie
				nearest_distance = distance_squared
		if nearest == null:
			break
		remaining_targets.erase(nearest)
		nearest.call("take_damage", 8 + 4 * stacks_value)
		var frost := get_stacks("frost_rune")
		if frost > 0 and nearest.has_method("apply_slow"):
			nearest.call("apply_slow", maxf(0.35, 1.0 - frost * 0.16),
				1.6 + frost * 0.3)


func _spawn_skill_wave(position: Vector3, radius: float, color: Color,
		duration: float = 0.48) -> void:
	if world == null or not is_instance_valid(world):
		return
	for index in range(_skill_waves.size() - 1, -1, -1):
		if not is_instance_valid(_skill_waves[index]):
			_skill_waves.remove_at(index)
	while _skill_waves.size() >= MAX_SKILL_WAVES:
		var oldest := _skill_waves.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var wave := SkillWave.new()
	wave.radius = maxf(0.1, radius)
	wave.tint = color
	wave.duration = maxf(0.12, duration)
	var wave_position := position
	wave_position.y = 0.025
	wave.position = world.to_local(wave_position)
	world.add_child(wave)
	_skill_waves.append(wave)


func _damage_area_targets(position: Vector3, radius: float,
		damage: int, excluded: Node3D = null) -> void:
	if world == null or not is_instance_valid(world) or damage <= 0:
		return
	var zombie_list: Array = world.get("zombies")
	for zombie_value in zombie_list:
		var zombie := zombie_value as Node3D
		if not is_instance_valid(zombie) or zombie == excluded \
				or not zombie.has_method("can_be_targeted") \
				or not bool(zombie.call("can_be_targeted")):
			continue
		var offset := zombie.global_position - position
		offset.y = 0.0
		if offset.length_squared() <= radius * radius:
			zombie.call("take_damage", damage)


func _refresh_aegis() -> void:
	var aegis := get_stacks("arcane_aegis") + get_stacks("soul_ward")
	if aegis <= 0:
		if is_instance_valid(_aegis_mesh):
			_aegis_mesh.visible = false
		return
	if _aegis_mesh == null or not is_instance_valid(_aegis_mesh):
		_aegis_mesh = MeshInstance3D.new()
		_aegis_mesh.name = "ArcaneAegisShell"
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 28
		sphere.rings = 14
		_aegis_mesh.mesh = sphere
		_aegis_mesh.position.y = 0.04
		_aegis_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_aegis_material = ShaderMaterial.new()
		_aegis_material.shader = AEGIS_SHADER
		_aegis_mesh.material_override = _aegis_material
		add_child(_aegis_mesh)
	_aegis_mesh.visible = true
	_aegis_material.set_shader_parameter("strength", 0.40 + aegis * 0.11)
	_aegis_material.set_shader_parameter("tint", Color(0.47, 0.34, 1.0, 1.0))
	_ensure_aegis_light()


func _ensure_aegis_light() -> void:
	if _aegis_light != null and is_instance_valid(_aegis_light):
		return
	_aegis_light = OmniLight3D.new()
	_aegis_light.name = "ArcaneEmberGlow"
	_aegis_light.position.y = 0.85
	_aegis_light.light_color = Color(0.46, 0.29, 1.0)
	_aegis_light.light_energy = 0.45
	_aegis_light.omni_range = 3.2
	_aegis_light.shadow_enabled = false
	add_child(_aegis_light)


func _add_orbit_flame(index: int) -> void:
	var orb := Node3D.new()
	orb.name = "OrbitingFlame%02d" % (index + 1)
	var core := FX.sphere(0.075, FX.CORE, 2.3, 12, 7)
	core.name = "ArcaneFlameCore"
	core.material_override.set_shader_parameter("turbulence", 0.72)
	orb.add_child(core)
	var shell := FX.sphere(0.13, FX.SHELL, 1.25, 12, 7)
	shell.name = "ArcaneFlameShell"
	shell.material_override.set_shader_parameter("rise", 0.06)
	orb.add_child(shell)
	var particles := FX.particles("OrbitFlameTrail", 4, 0.40, false, true)
	particles.position = Vector3.ZERO
	var flame_quad := particles.draw_pass_1 as QuadMesh
	flame_quad.size = Vector2(0.25, 0.38)
	particles.emitting = true
	orb.add_child(particles)
	add_child(orb)
	_orbit_nodes.append(orb)


func _update_orbit_positions() -> void:
	var count := _orbit_nodes.size()
	var stack_count := get_stacks("cinder_orbit")
	var radius := 1.50 + float(maxi(0, stack_count - 1)) * 0.28
	for index in count:
		var angle := _orbit_clock * (1.95 + float(count) * 0.12) \
			+ TAU * float(index) / float(count)
		var orb := _orbit_nodes[index]
		if not is_instance_valid(orb):
			continue
		orb.position = Vector3(cos(angle) * radius,
			0.74 + sin(angle * 2.0 + float(index)) * 0.11,
			sin(angle) * radius)
		orb.rotation.y = -angle


func _damage_nearby_zombies() -> void:
	if world == null or not world.has_method("living_zombie_count"):
		return
	var orbit_stacks := get_stacks("cinder_orbit")
	var damage := 9 + (orbit_stacks - 1) * 6
	var radius := 2.30 + orbit_stacks * 0.35
	var zombie_list: Array = world.get("zombies")
	for zombie in zombie_list:
		if not is_instance_valid(zombie) or not zombie.has_method("can_be_targeted") \
				or not bool(zombie.call("can_be_targeted")):
			continue
		var offset: Vector2 = Vector2(zombie.global_position.x - player.global_position.x,
			zombie.global_position.z - player.global_position.z)
		if offset.length_squared() <= radius * radius:
			zombie.call("take_damage", damage)


func _spawn_nova(position: Vector3) -> void:
	_spawn_skill_wave(position, _nova_radius, Color("#ffba55"), 0.54)
	_damage_area_targets(position, _nova_radius, _nova_damage)
