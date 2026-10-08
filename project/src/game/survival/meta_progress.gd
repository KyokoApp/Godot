class_name SurvivalMetaProgress
extends RefCounted
## Koin dan peningkatan kecil yang bertahan antar-run di perangkat ini.

signal coins_changed(total: int)
signal upgrades_changed

const SAVE_PATH := "user://survival_meta.cfg"
const SAVE_INTERVAL := 20.0
const UPGRADE_DEFS: Array[Dictionary] = [
	{"id": "damage", "name": "FOKUS SIHIR", "description": "+2% damage sihir per level",
		"base_cost": 50, "max_level": 12},
	{"id": "fire_rate", "name": "MANTRA KILAT", "description": "Cooldown tembak -1,5% per level",
		"base_cost": 60, "max_level": 12},
	{"id": "max_health", "name": "JANTUNG TEGAR", "description": "+4 HP maksimum per level",
		"base_cost": 45, "max_level": 12},
	{"id": "move_speed", "name": "LANGKAH RINGAN", "description": "+0,5% kecepatan lari per level",
		"base_cost": 55, "max_level": 12},
	{"id": "critical_chance", "name": "MATA TAJAM", "description": "+0,7% peluang critical per level",
		"base_cost": 70, "max_level": 12},
	{"id": "critical_power", "name": "SIGIL TAJAM", "description": "+3% damage critical per level",
		"base_cost": 72, "max_level": 12},
	{"id": "armor", "name": "PELINDUNG ARKANA", "description": "+0,4% pengurangan damage per level",
		"base_cost": 65, "max_level": 12},
	{"id": "heal_on_kill", "name": "PANEN KEHIDUPAN", "description": "+1 HP setiap kill per level",
		"base_cost": 68, "max_level": 8},
	{"id": "experience", "name": "PANEN ARWAH", "description": "+2% EXP dari kill per level",
		"base_cost": 58, "max_level": 10},
	{"id": "lock_range", "name": "PANDANGAN PEMBURU",
		"description": "+0,6 m jangkauan auto-lock per level",
		"base_cost": 62, "max_level": 10},
	{"id": "projectile_speed", "name": "API MELAJU",
		"description": "+2% kecepatan proyektil per level",
		"base_cost": 58, "max_level": 10},
	{"id": "coin_bonus", "name": "KANTONG LEBAR", "description": "+3% koin dari kill per level",
		"base_cost": 82, "max_level": 10},
	{"id": "shield_capacity", "name": "PERISAI AWAL", "description": "+5 kapasitas shield per level",
		"base_cost": 76, "max_level": 10},
]

var coins := 0
var levels: Dictionary = {}
var _save_path := SAVE_PATH
var _save_clock := 0.0
var _dirty := false


func _init(save_path: String = SAVE_PATH) -> void:
	_save_path = save_path
	_load()


func get_upgrade_level(upgrade_id: String) -> int:
	return maxi(0, int(levels.get(upgrade_id, 0)))


func upgrade_cost(upgrade_id: String) -> int:
	var definition := _definition_for(upgrade_id)
	if definition.is_empty():
		return 0
	var level := get_upgrade_level(upgrade_id)
	var base_cost := int(definition.get("base_cost", 50))
	var growth := 1.0 + float(level) * 0.16 + float(level * level) * 0.008
	return maxi(1, roundi(float(base_cost) * growth))


func get_upgrades() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition in UPGRADE_DEFS:
		var info := definition.duplicate(true)
		var level := get_upgrade_level(str(info.get("id", "")))
		var maximum := int(info.get("max_level", 1))
		info["level"] = level
		info["cost"] = upgrade_cost(str(info.get("id", "")))
		info["maxed"] = level >= maximum
		result.append(info)
	return result


func get_modifiers() -> Dictionary:
	return {
		"damage_multiplier": 1.0 + get_upgrade_level("damage") * 0.02,
		"cooldown_multiplier": maxf(0.82, 1.0 - get_upgrade_level("fire_rate") * 0.015),
		"health_bonus": get_upgrade_level("max_health") * 4,
		"movement_speed_multiplier": 1.0 + get_upgrade_level("move_speed") * 0.005,
		"critical_chance": get_upgrade_level("critical_chance") * 0.007,
		"critical_multiplier_bonus": get_upgrade_level("critical_power") * 0.03,
		"damage_reduction": get_upgrade_level("armor") * 0.004,
		"heal_on_kill": get_upgrade_level("heal_on_kill"),
		"xp_multiplier": 1.0 + get_upgrade_level("experience") * 0.02,
		"magic_lock_range_bonus": get_upgrade_level("lock_range") * 0.6,
		"projectile_speed_multiplier": 1.0 + get_upgrade_level("projectile_speed") * 0.02,
		"coin_multiplier": 1.0 + get_upgrade_level("coin_bonus") * 0.03,
		"shield_capacity_bonus": get_upgrade_level("shield_capacity") * 5,
	}


func add_coins(amount: int) -> int:
	if amount <= 0:
		return coins
	coins += amount
	_dirty = true
	coins_changed.emit(coins)
	return coins


func purchase_upgrade(upgrade_id: String) -> bool:
	var definition := _definition_for(upgrade_id)
	if definition.is_empty():
		return false
	var level := get_upgrade_level(upgrade_id)
	if level >= int(definition.get("max_level", 1)):
		return false
	var cost := upgrade_cost(upgrade_id)
	if coins < cost:
		return false
	coins -= cost
	levels[upgrade_id] = level + 1
	_dirty = true
	_save_clock = 0.0
	save()
	coins_changed.emit(coins)
	upgrades_changed.emit()
	return true


func tick_save(delta: float) -> void:
	if not _dirty:
		return
	_save_clock += maxf(0.0, delta)
	if _save_clock >= SAVE_INTERVAL:
		_save_clock = 0.0
		save()


func save() -> bool:
	var config := ConfigFile.new()
	config.set_value("progress", "coins", maxi(0, coins))
	for definition in UPGRADE_DEFS:
		var upgrade_id := str(definition.get("id", ""))
		config.set_value("upgrades", upgrade_id, get_upgrade_level(upgrade_id))
	var error := config.save(_save_path)
	if error == OK:
		_dirty = false
	return error == OK


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(_save_path) != OK:
		return
	coins = maxi(0, int(config.get_value("progress", "coins", 0)))
	levels.clear()
	for definition in UPGRADE_DEFS:
		var upgrade_id := str(definition.get("id", ""))
		var maximum := int(definition.get("max_level", 1))
		levels[upgrade_id] = clampi(
			int(config.get_value("upgrades", upgrade_id, 0)), 0, maximum)
	_dirty = false
	_save_clock = 0.0


func _definition_for(upgrade_id: String) -> Dictionary:
	for definition in UPGRADE_DEFS:
		if str(definition.get("id", "")) == upgrade_id:
			return definition
	return {}
