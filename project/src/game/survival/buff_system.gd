class_name SurvivalBuffSystem
extends Node3D
## Mengurus stack buff, statistik run, serta visual sihir bertumpu pada karakter.

signal buffs_changed(stacks: Dictionary)

const Catalog = preload("res://src/game/survival/buff_catalog.gd")
const FX = preload("res://src/game/attack_fx/fx_resources.gd")
const FireBurst = preload("res://src/game/fire_burst.gd")
const AEGIS_SHADER = preload("res://src/game/survival/aegis_shell.gdshader")

const XP_BASE := 80
const XP_GROWTH := 18
const ORBIT_LIMIT := 5

var player: Node3D
var fire_pet: Node3D
var world: Node3D
var stacks: Dictionary = {}
var magic_lock_range_bonus := 0.0
var xp_multiplier := 1.0

var _aegis_mesh: MeshInstance3D
var _aegis_material: ShaderMaterial
var _aegis_light: OmniLight3D
var _orbit_nodes: Array[Node3D] = []
var _orbit_clock := 0.0
var _orbit_damage_clock := 0.0
var _shield_flash := 0.0
var _nova_active := false
var _nova_damage := 0
var _nova_radius := 0.0
var _burn_stacks := 0


func _ready() -> void:
	name = "SurvivalBuffSystem"
	if player != null and player.has_signal("survival_stats_changed"):
		player.connect("survival_stats_changed", _on_player_stats_changed)
	if fire_pet != null and fire_pet.has_signal("impact_landed"):
		fire_pet.connect("impact_landed", _on_magic_impact)
	_apply_modifiers("")


func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	global_position = player.global_position
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
		if current >= int(card.get("max_stacks", 1)):
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
	if current >= maximum:
		return false
	stacks[buff_id] = current + 1
	_apply_modifiers(buff_id)
	buffs_changed.emit(stacks.duplicate(true))
	return true


func set_orbit_stacks(count: int) -> void:
	var desired := 0
	if count > 0:
		desired = mini(ORBIT_LIMIT, 2 + count)
	while _orbit_nodes.size() < desired:
		_add_orbit_flame(_orbit_nodes.size())
	while _orbit_nodes.size() > desired:
		var orb := _orbit_nodes.pop_back()
		if is_instance_valid(orb):
			orb.queue_free()
	if count > 0:
		_ensure_aegis_light()


func on_zombie_killed(zombie: Node3D) -> void:
	var siphon := get_stacks("soul_siphon")
	if siphon > 0 and is_instance_valid(player):
		player.call("heal", 8 * siphon)
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
	_burn_stacks = 0
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
	var ember := get_stacks("ember_core") + get_stacks("ascendant_sigil") * 0.17
	var rapid := get_stacks("rapid_cast")
	var aegis := get_stacks("arcane_aegis")
	var overcharge := get_stacks("overcharge")
	var volley := get_stacks("echo_volley")
	var seeker := get_stacks("seeking_flame")
	var vitality := get_stacks("vitality")
	var harvest := get_stacks("harvest")
	var shield_refill := 70 if last_buff_id == "arcane_aegis" else 0
	if is_instance_valid(player):
		player.call("set_survival_bonuses", vitality * 25, aegis * 70,
			shield_refill, aegis * 0.07)
	if is_instance_valid(fire_pet):
		fire_pet.call("set_survival_modifiers", {
			"damage_multiplier": 1.0 + 0.18 * ember,
			"cooldown_multiplier": maxf(0.54, 1.0 - 0.10 * rapid),
			"critical_chance": overcharge * 0.08,
			"critical_multiplier": 2.0 + 0.12 * overcharge,
			"extra_shot_chance": volley * 0.12,
			"homing_turn_rate_multiplier": 1.0 + seeker * 0.18,
		})
	magic_lock_range_bonus = get_stacks("long_reach") * 7.0
	xp_multiplier = 1.0 + 0.20 * harvest
	_nova_damage = 30 + 22 * (get_stacks("volatile_nova") - 1)
	_nova_radius = 3.4 + 0.3 * get_stacks("volatile_nova")
	_burn_stacks = get_stacks("burning_brand")
	set_orbit_stacks(get_stacks("cinder_orbit"))
	_refresh_aegis()


func _on_player_stats_changed() -> void:
	if _aegis_material != null:
		_shield_flash = 1.0


func _on_magic_impact(target: Node3D, _damage: int, _critical: bool) -> void:
	if _burn_stacks <= 0 or not is_instance_valid(target):
		return
	if target.has_method("apply_burn") and target.has_method("can_be_targeted") \
			and bool(target.call("can_be_targeted")):
		target.call("apply_burn", 5 + 3 * (_burn_stacks - 1), 2.5)


func _refresh_aegis() -> void:
	var aegis := get_stacks("arcane_aegis")
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
	var core := FX.sphere(0.085, FX.CORE, 2.8)
	core.name = "ArcaneFlameCore"
	core.material_override.set_shader_parameter("turbulence", 0.8)
	orb.add_child(core)
	var shell := FX.sphere(0.15, FX.SHELL, 1.75)
	shell.name = "ArcaneFlameShell"
	shell.material_override.set_shader_parameter("rise", 0.06)
	orb.add_child(shell)
	var particles := FX.particles("OrbitFlameTrail", 9, 0.62, false, true)
	particles.position = Vector3.ZERO
	particles.emitting = true
	orb.add_child(particles)
	add_child(orb)
	_orbit_nodes.append(orb)


func _update_orbit_positions() -> void:
	var count := _orbit_nodes.size()
	var radius := 1.13 + float(count - 3) * 0.12
	for index in count:
		var angle := _orbit_clock * (2.0 + float(count) * 0.14) \
			+ TAU * float(index) / float(count)
		var orb := _orbit_nodes[index]
		if not is_instance_valid(orb):
			continue
		orb.position = Vector3(cos(angle) * radius,
			0.74 + sin(angle * 2.0 + float(index)) * 0.17,
			sin(angle) * radius)
		orb.rotation.y = -angle


func _damage_nearby_zombies() -> void:
	if world == null or not world.has_method("living_zombie_count"):
		return
	var orbit_stacks := get_stacks("cinder_orbit")
	var damage := 9 + (orbit_stacks - 1) * 6
	var radius := 2.65 + orbit_stacks * 0.16
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
	if world == null or not is_instance_valid(world):
		return
	var burst := FireBurst.new()
	burst.surface_normal = Vector3.UP
	burst.position = world.to_local(position + Vector3(0, 0.04, 0))
	world.add_child(burst)
	var zombie_list: Array = world.get("zombies")
	for zombie in zombie_list:
		if not is_instance_valid(zombie) or not zombie.has_method("can_be_targeted") \
				or not bool(zombie.call("can_be_targeted")):
			continue
		var offset := zombie.global_position - position
		offset.y = 0.0
		if offset.length_squared() <= _nova_radius * _nova_radius:
			zombie.call("take_damage", _nova_damage)
