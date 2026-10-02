extends Node3D
## Short pose echoes wrapped in soft smoke. No bright ribbons or sphere shell.

const Character = preload("res://src/game/character/aurelia_visual.gd")
const Ghosts = preload("res://src/game/speed/afterimage_trail.gd")
const SMOKE = preload("res://src/game/speed/smoke.gdshader")
const WASH = preload("res://src/game/speed/speed_wash.gdshader")
const TINT := Color("ae65ff")
const PUFFS := 10
var character: Character
var environment: Environment
var strength := 0.0
var tint := TINT
var wash: ColorRect
var ghosts: Ghosts
var _puffs: Array[MeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _ages: Array[float] = []
var _clock := 0.0
var _next := 0
var _wash_material: ShaderMaterial
var _previous := Vector3.ZERO
var _time := 0.0
var _glow_before := false
var _glow_strength_before := 0.0
var _glow_threshold_before := 1.0


func _ready() -> void:
	ghosts = Ghosts.new()
	ghosts.character = character
	add_child(ghosts)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.15, 1.45)
	for index in range(PUFFS):
		var puff := MeshInstance3D.new()
		puff.mesh = quad
		var material := ShaderMaterial.new()
		material.shader = SMOKE
		puff.material_override = material
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(puff)
		_puffs.append(puff)
		_materials.append(material)
		_ages.append(1.0)
	var layer := CanvasLayer.new()
	layer.layer = 0 # World wash below the existing HUD's layer 1.
	add_child(layer)
	wash = ColorRect.new()
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash_material = ShaderMaterial.new()
	_wash_material.shader = WASH
	wash.material = _wash_material
	layer.add_child(wash)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if environment != null:
		_glow_before = environment.glow_enabled
		_glow_strength_before = environment.glow_strength
		_glow_threshold_before = environment.glow_hdr_threshold
	_previous = character.global_position
	clear()


func clear() -> void:
	strength = 0
	ghosts.clear()
	for index in range(PUFFS):
		_ages[index] = 1.0
		_puffs[index].hide()
	_clock = 0
	_apply()


func update_motion(delta: float, speed: float, boosted: bool) -> void:
	var origin := character.global_position
	if origin.distance_to(_previous) > 3.0:
		clear()
	_previous = origin
	tint = TINT
	_time += delta
	var target := 1.0 if boosted and speed > 0.3 else 0.0
	strength = lerpf(strength, target, 1.0 - exp(-delta * (8.0 if target > 0 else 11.0)))
	if strength < 0.003 and target == 0:
		clear()
		return
	ghosts.update_motion(delta, speed, boosted)
	_update_smoke(delta, origin, target > 0)
	_apply()


func _apply() -> void:
	var active := strength > 0.003
	wash.visible = active
	_wash_material.set_shader_parameter("strength", strength * 0.65)
	_wash_material.set_shader_parameter("tint", tint)
	if environment != null:
		environment.glow_enabled = active or _glow_before
		var base := _glow_strength_before if _glow_before else 0.0
		environment.glow_strength = maxf(base, strength * 0.3) if active \
			else _glow_strength_before
		environment.glow_hdr_threshold = 1.1 if active else _glow_threshold_before


func _update_smoke(delta: float, origin: Vector3, emitting: bool) -> void:
	for index in range(PUFFS):
		_ages[index] += delta
		var life := maxf(0, 1.0 - _ages[index] / 0.48)
		_puffs[index].visible = life > 0
		_puffs[index].position.y += delta * 0.18
		_materials[index].set_shader_parameter("opacity", life * life * 0.24)
	_clock += delta
	if not emitting or _clock < 0.06:
		return
	_clock = fmod(_clock, 0.06)
	var puff := _puffs[_next]
	puff.global_position = origin + Vector3(sin(_time * 7) * 0.18, 0.75, 0)
	_ages[_next] = 0
	_materials[_next].set_shader_parameter("tint", tint)
	_materials[_next].set_shader_parameter("phase", _time)
	_materials[_next].set_shader_parameter("opacity", 0.24)
	puff.show()
	_next = (_next + 1) % PUFFS


func _exit_tree() -> void:
	if environment != null:
		environment.glow_enabled = _glow_before
		environment.glow_strength = _glow_strength_before
		environment.glow_hdr_threshold = _glow_threshold_before
