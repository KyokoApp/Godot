extends Node3D
## One opt-in, non-gory sparring encounter. No enemy outside the challenge.
const Character = preload("res://src/game/mannequin.gd")
const FightLibrary = preload("res://src/game/combat/fight_library.gd")
const Shape = preload("res://src/game/arena/arena_shape.gd")
const Rune = preload("res://src/game/ui/rune_button.gd")
const CombatFX = preload("res://src/game/combat/arena_combat_fx.gd")
const REACH := 2.5
const MAX_HP := 100
const COMBO_WINDOW := 3.0
const MAX_COMBO := 4
const ZOMBIE_ATTACK_CLIPS := [
	FightLibrary.MELEE_HOOK,
	FightLibrary.ZOMBIE_SCRATCH,
	FightLibrary.OVERHAND_THROW,
]
const ENEMY_ATTACK_CLIPS := [
	FightLibrary.MELEE_HOOK,
	FightLibrary.ZOMBIE_SCRATCH,
	FightLibrary.SWORD_REGULAR_COMBO,
	FightLibrary.SWORD_REGULAR_A,
	FightLibrary.SWORD_REGULAR_B,
	FightLibrary.SWORD_REGULAR_C,
	FightLibrary.SWORD_HEAVY_COMBO,
	FightLibrary.SHIELD_ONE_SHOT,
	FightLibrary.OVERHAND_THROW,
]
var game: Node3D
var active := false
var finishing := false
var player_hp := MAX_HP
var enemy_hp := MAX_HP
var sword_mode := false
var enemy: CharacterBody3D
var enemy_visual: Character
var prompt: Rune
var style_button: Rune
var evade_button: Rune
var enemy_hud: Control
var player_hud: PanelContainer
var status: Label
var combat_callout: Label
var combat_fx: Node3D
var player_hp_bar: ProgressBar
var enemy_hp_bar: ProgressBar
var player_hp_value: Label
var artifact: Node3D
var player_cooldown := 0.0
var enemy_cooldown := 1.0
var _player_hit := -1.0
var _enemy_hit := -1.0
var _player_combo := 0
var _last_player_attack := 0.0
var _player_hit_range := REACH
var _enemy_attack_range := REACH
var _player_damage := 25
var _enemy_damage := 15
var _player_attack_tint := Color(1.0, 0.58, 0.25)
var _enemy_attack_tint := Color(0.68, 0.82, 1.0)
var _player_swing_delay := -1.0
var _enemy_swing_delay := -1.0
var _player_attack_clip := ""
var _combo_hits := 0
var _last_combo_hit := -100.0
var _callout_time := 0.0
var _player_invulnerable := 0.0
var _enemy_invulnerable := 0.0
var _enemy_guarding := false
var _enemy_zombie_style := false
var _enemy_locomotion_clip := ""
var _enemy_dashing := false
var _enemy_dash_cooldown := 0.0
var _enemy_evade_cooldown := 0.0
var _next_player_evade := false
var _player_followups: Array[String] = []
var _enemy_followups: Array[String] = []
var _rng := RandomNumberGenerator.new()
var _finish_time := 0.0
var _time := 0.0


func _ready() -> void:
	name = "ArenaChallenge"
	combat_fx = CombatFX.new()
	combat_fx.name = "ArenaCombatFX"
	combat_fx.set("camera", game._orbit.camera)
	add_child(combat_fx)
	artifact = Node3D.new()
	artifact.position = Vector3(Shape.CENTER.x, Shape.HEIGHT + 1.8, Shape.CENTER.y)
	add_child(artifact)
	var gem := MeshInstance3D.new()
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.45, 0.9, 0.45)
	gem.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("c3eaff")
	material.emission_enabled = true
	material.emission = Color("8bc9ff")
	gem.material_override = material
	artifact.add_child(gem)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.65
	torus.outer_radius = 0.69
	ring.mesh = torus
	ring.material_override = material
	artifact.add_child(ring)
	var layer := CanvasLayer.new()
	add_child(layer)
	prompt = Rune.new()
	prompt.rectangular = true
	prompt.text = "✧  Mulai tantangan"
	prompt.add_theme_font_size_override("font_size", 20)
	layer.add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	prompt.offset_left = -430
	prompt.offset_right = -150
	prompt.offset_top = -26
	prompt.offset_bottom = 26
	prompt.pressed.connect(start)
	game._orbit.interact_exclusion = prompt
	enemy_hud = Control.new()
	enemy_hud.name = "EnemyBossHealth"
	layer.add_child(enemy_hud)
	enemy_hud.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	enemy_hud.offset_left = -260
	enemy_hud.offset_right = 260
	enemy_hud.offset_top = 14
	enemy_hud.offset_bottom = 48
	status = Label.new()
	status.text = "MANNEQUIN"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 13)
	status.add_theme_color_override("font_color", Color("f1e7d1"))
	enemy_hud.add_child(status)
	status.position = Vector2.ZERO
	status.size = Vector2(520, 18)
	enemy_hp_bar = _make_health_bar(Color("bd3948"), Color(0.10, 0.07, 0.09, 0.9), 6)
	enemy_hp_bar.position = Vector2(0, 23)
	enemy_hp_bar.size = Vector2(520, 6)
	enemy_hud.add_child(enemy_hp_bar)
	_make_player_hud(layer)
	combat_callout = Label.new()
	combat_callout.name = "ArenaCombatCallout"
	combat_callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combat_callout.add_theme_font_size_override("font_size", 18)
	combat_callout.add_theme_color_override("font_color", Color("bcefff"))
	combat_callout.add_theme_color_override("font_shadow_color", Color(0.03, 0.05, 0.1, 0.9))
	combat_callout.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(combat_callout)
	combat_callout.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	combat_callout.offset_left = -210
	combat_callout.offset_right = 210
	combat_callout.offset_top = 54
	combat_callout.offset_bottom = 82
	style_button = Rune.new()
	style_button.name = "FightStyleToggle"
	style_button.rectangular = true
	style_button.text = "Mode: Melee"
	style_button.add_theme_font_size_override("font_size", 14)
	layer.add_child(style_button)
	style_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	style_button.offset_left = -406
	style_button.offset_right = -270
	style_button.offset_top = -205
	style_button.offset_bottom = -163
	style_button.pressed.connect(toggle_attack_style)
	game._orbit.combat_style_exclusion = style_button
	evade_button = Rune.new()
	evade_button.name = "FightEvade"
	evade_button.rectangular = true
	evade_button.text = "Hindar"
	evade_button.tooltip_text = "Tangkis, geser, atau lompat menghindar"
	evade_button.add_theme_font_size_override("font_size", 14)
	layer.add_child(evade_button)
	evade_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	evade_button.offset_left = -394
	evade_button.offset_right = -274
	evade_button.offset_top = -265
	evade_button.offset_bottom = -220
	evade_button.pressed.connect(evade)
	game._orbit.evasion_exclusion = evade_button
	prompt.hide()
	enemy_hud.hide()
	player_hud.hide()
	combat_callout.hide()
	style_button.hide()
	evade_button.hide()
	_update_health_bars()


func _make_player_hud(layer: CanvasLayer) -> void:
	player_hud = PanelContainer.new()
	player_hud.name = "PlayerHealth"
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.025, 0.035, 0.07, 0.86)
	panel.border_color = Color(0.44, 0.84, 0.78, 0.7)
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(8)
	panel.content_margin_left = 9
	panel.content_margin_right = 9
	panel.content_margin_top = 5
	panel.content_margin_bottom = 5
	player_hud.add_theme_stylebox_override("panel", panel)
	layer.add_child(player_hud)
	player_hud.position = Vector2(24, 210)
	player_hud.size = Vector2(176, 44)
	player_hud.custom_minimum_size = player_hud.size
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 2)
	player_hud.add_child(content)
	var heading := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = "KAMU"
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color("e4e9f3"))
	heading.add_child(name_label)
	player_hp_value = Label.new()
	player_hp_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	player_hp_value.add_theme_font_size_override("font_size", 11)
	player_hp_value.add_theme_color_override("font_color", Color("f3f5fa"))
	heading.add_child(player_hp_value)
	content.add_child(heading)
	player_hp_bar = _make_health_bar(Color("70dfce"), Color(0.11, 0.13, 0.19, 1.0), 5)
	content.add_child(player_hp_bar)


func _make_health_bar(fill_color: Color, track_color: Color, thickness: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = MAX_HP
	bar.value = MAX_HP
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, thickness)
	var background := StyleBoxFlat.new()
	background.bg_color = track_color
	background.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


func _update_health_bars() -> void:
	if player_hp_bar == null or enemy_hp_bar == null:
		return
	player_hp_bar.value = player_hp
	enemy_hp_bar.value = enemy_hp
	player_hp_value.text = "%d / %d" % [player_hp, MAX_HP]

func nearby() -> bool:
	return game.inside_arena and game._player.position.distance_to(
		Vector3(Shape.CENTER.x, Shape.HEIGHT, Shape.CENTER.y)) < 3.5


func start() -> void:
	if active or finishing or not nearby() or game._graphics_drawer.visible:
		return
	if not game._visual.prepare_fight():
		return
	var missing: PackedStringArray = game._visual._fight_driver.missing_required_clips()
	if not missing.is_empty():
		push_error("Arena: klip UAL2 hilang: " + ", ".join(missing))
		return
	_rng.randomize()
	active = true
	sword_mode = false
	game._visual.set_fight_sword(false)
	style_button.text = "Mode: Melee"
	player_hp = MAX_HP
	enemy_hp = MAX_HP
	player_cooldown = 0.0
	enemy_cooldown = 1.0
	_player_hit = -1.0
	_enemy_hit = -1.0
	_player_combo = 0
	_last_player_attack = _time - COMBO_WINDOW - 1.0
	_player_hit_range = REACH
	_enemy_attack_range = REACH
	_player_damage = 25
	_player_swing_delay = -1.0
	_enemy_swing_delay = -1.0
	_player_attack_clip = ""
	_combo_hits = 0
	_last_combo_hit = -100.0
	_callout_time = 0.0
	_player_invulnerable = 0.0
	_enemy_invulnerable = 0.0
	_enemy_guarding = false
	_enemy_zombie_style = _rng.randf() < 0.35
	_enemy_locomotion_clip = ""
	_enemy_dashing = false
	_enemy_dash_cooldown = 0.0
	_enemy_evade_cooldown = 0.0
	_next_player_evade = false
	_player_followups.clear()
	_enemy_followups.clear()
	game._pet.casting = false
	game._visual.cancel_fight()
	enemy = CharacterBody3D.new()
	enemy.name = "ChallengeMannequin"
	enemy.collision_layer = 4
	_add_collision()
	add_child(enemy)
	enemy.position = Vector3(Shape.CENTER.x + 5, Shape.HEIGHT + 0.1, Shape.CENTER.y)
	enemy_visual = Character.new()
	enemy.add_child(enemy_visual)
	if not enemy_visual.prepare_fight():
		reset()
		return
	var enemy_missing: PackedStringArray = enemy_visual._fight_driver.missing_required_clips()
	if not enemy_missing.is_empty():
		push_error("Arena opponent: klip UAL2 hilang: " + ", ".join(enemy_missing))
		reset()
		return
	enemy_visual.set_fight_sword(not _enemy_zombie_style)
	artifact.hide()
	prompt.hide()
	combat_callout.hide()
	status.text = "ZOMBIE SPARRER" if _enemy_zombie_style else "MANNEQUIN"
	enemy_hud.show()
	player_hud.show()
	style_button.show()
	evade_button.show()
	_update_health_bars()


func _add_collision() -> void:
	enemy.collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.9
	enemy.add_child(collider)


func toggle_attack_style() -> void:
	if not active or finishing or game._visual.action_time > 0:
		return
	sword_mode = not sword_mode
	style_button.text = "Mode: Pedang" if sword_mode else "Mode: Melee"
	game._visual.set_fight_sword(sword_mode)
	_player_combo = 0
	_player_followups.clear()


func _valid_followups(driver: FightLibrary, clips: Array[String]) -> Array[String]:
	var valid: Array[String] = []
	for clip in clips:
		if driver.has_clip(clip):
			valid.append(clip)
	return valid


func _followup_duration(driver: FightLibrary, clips: Array[String]) -> float:
	var total := 0.0
	for clip in clips:
		total += driver.clip_length(clip)
	return total


func _attack_tint(clip: String) -> Color:
	var tint := Color(1.0, 0.53, 0.25)
	match clip:
		FightLibrary.SWORD_REGULAR_A, FightLibrary.SWORD_REGULAR_COMBO:
			tint = Color(0.36, 0.82, 1.0)
		FightLibrary.SWORD_REGULAR_B:
			tint = Color(0.52, 0.62, 1.0)
		FightLibrary.SWORD_REGULAR_C:
			tint = Color(0.72, 0.50, 1.0)
		FightLibrary.SWORD_HEAVY_COMBO, FightLibrary.OVERHAND_THROW:
			tint = Color(1.0, 0.76, 0.30)
		FightLibrary.SWORD_BLOCK, FightLibrary.SHIELD_DASH, FightLibrary.SHIELD_ONE_SHOT:
			tint = Color(0.54, 0.88, 1.0)
		FightLibrary.ZOMBIE_SCRATCH:
			tint = Color(0.62, 1.0, 0.42)
	return tint


func _show_combat_callout(text: String, tint: Color) -> void:
	combat_callout.text = text.replace("_", " ").to_upper()
	combat_callout.add_theme_color_override("font_color", tint)
	combat_callout.show()
	_callout_time = 1.2


func attack() -> void:
	if not active or finishing or player_cooldown > 0 or game._graphics_drawer.visible:
		return
	if game._visual.action_time > 0:
		return
	var direction: Vector3 = enemy.position - game._player.position
	game._visual.rotation.y = atan2(-direction.x, -direction.z)
	if _time - _last_player_attack > COMBO_WINDOW:
		_player_combo = 0

	var clip: String
	var followups: Array[String] = []
	_player_hit_range = REACH
	if sword_mode:
		match _player_combo:
			0:
				clip = FightLibrary.SWORD_REGULAR_COMBO
			1:
				clip = FightLibrary.SWORD_REGULAR_A
				followups.append(FightLibrary.SWORD_REGULAR_A_RECOVERY)
			2:
				clip = FightLibrary.SWORD_REGULAR_B
				followups.append(FightLibrary.SWORD_REGULAR_B_RECOVERY)
			3:
				clip = FightLibrary.SWORD_REGULAR_C
			_:
				clip = FightLibrary.SWORD_HEAVY_COMBO
		_player_damage = 35 if _player_combo == MAX_COMBO else 25
	else:
		match _player_combo % 3:
			0:
				clip = FightLibrary.MELEE_HOOK
				followups.append(FightLibrary.MELEE_HOOK_RECOVERY)
			1:
				clip = FightLibrary.ZOMBIE_SCRATCH
				_player_damage = 20
			_:
				clip = FightLibrary.OVERHAND_THROW
				_player_damage = 30
				_player_hit_range = 7.5
		if _player_combo % 3 == 0:
			_player_damage = 25

	var length: float = game._visual.play_fight(clip)
	if length <= 0:
		return
	_player_followups = _valid_followups(game._visual._fight_driver, followups)
	player_cooldown = maxf(length + _followup_duration(
		game._visual._fight_driver, _player_followups) + 0.15, 0.8)
	_player_attack_clip = clip
	_player_attack_tint = _attack_tint(clip)
	_player_swing_delay = maxf(length * 0.28, 0.045)
	_player_hit = length * 0.45
	_player_combo = (_player_combo + 1) % (MAX_COMBO + 1)
	_last_player_attack = _time
	_show_combat_callout(clip, _player_attack_tint)


func evade() -> void:
	if not active or finishing or player_cooldown > 0 or game._graphics_drawer.visible:
		return
	if game._visual.action_time > 0:
		return
	var clip: String
	var followups: Array[String] = []
	if sword_mode:
		clip = FightLibrary.SWORD_BLOCK
	else:
		_next_player_evade = not _next_player_evade
		if _next_player_evade:
			clip = FightLibrary.SLIDE_START
			followups.append(FightLibrary.SLIDE_LOOP)
			followups.append(FightLibrary.SLIDE_EXIT)
		else:
			clip = FightLibrary.NINJA_JUMP_START
			followups.append(FightLibrary.NINJA_JUMP_IDLE_LOOP)
			followups.append(FightLibrary.NINJA_JUMP_LAND)
	var length: float = game._visual.play_fight(clip)
	if length <= 0:
		return
	var evade_point: Vector3 = game._visual.global_position + Vector3.UP * 1.05
	if sword_mode:
		combat_fx.call("spawn_guard", evade_point, Color(0.48, 0.86, 1.0), "PARRY")
		game._orbit.combat_shake(0.025, 0.08)
		_show_combat_callout("SWORD BLOCK", Color(0.62, 0.90, 1.0))
	else:
		combat_fx.call("spawn_dodge", game._visual.global_position, Color(0.55, 0.92, 1.0))
		_show_combat_callout("DODGE", Color(0.66, 0.96, 1.0))
	_player_hit = -1.0
	_player_followups = _valid_followups(game._visual._fight_driver, followups)
	var evade_duration := length + _followup_duration(
		game._visual._fight_driver, _player_followups)
	player_cooldown = maxf(evade_duration + 0.1, 0.7)
	_player_invulnerable = evade_duration
	_player_combo = 0


func _advance_player_followup() -> void:
	if game._visual.action_time > 0.0 or _player_followups.is_empty():
		return
	var clip: String = _player_followups.pop_front()
	if game._visual.play_fight(clip) <= 0.0:
		_player_followups.clear()


func _advance_enemy_followup() -> void:
	if not is_instance_valid(enemy_visual):
		return
	if enemy_visual.action_time > 0.0 or _enemy_followups.is_empty():
		return
	var clip: String = _enemy_followups.pop_front()
	if enemy_visual.play_fight(clip) <= 0.0:
		_enemy_followups.clear()


func _choose_enemy_attack() -> String:
	if _enemy_zombie_style:
		var zombie_index := _rng.randi_range(0, ZOMBIE_ATTACK_CLIPS.size() - 1)
		var zombie_clip: String = ZOMBIE_ATTACK_CLIPS[zombie_index]
		return zombie_clip
	var index := _rng.randi_range(0, ENEMY_ATTACK_CLIPS.size() - 1)
	var clip: String = ENEMY_ATTACK_CLIPS[index]
	return clip


func _start_enemy_attack(clip: String) -> void:
	_enemy_guarding = false
	_enemy_invulnerable = 0.0
	_enemy_swing_delay = -1.0
	var followups: Array[String] = []
	if clip == FightLibrary.MELEE_HOOK:
		followups.append(FightLibrary.MELEE_HOOK_RECOVERY)
	elif clip == FightLibrary.SWORD_REGULAR_A:
		followups.append(FightLibrary.SWORD_REGULAR_A_RECOVERY)
	elif clip == FightLibrary.SWORD_REGULAR_B:
		followups.append(FightLibrary.SWORD_REGULAR_B_RECOVERY)
	var length: float = enemy_visual.play_fight(clip)
	if length <= 0.0:
		return
	_enemy_followups = _valid_followups(enemy_visual._fight_driver, followups)
	_enemy_damage = 20 if clip == FightLibrary.SHIELD_ONE_SHOT else 15
	_enemy_attack_range = 7.5 if clip == FightLibrary.OVERHAND_THROW else REACH
	_enemy_attack_tint = _attack_tint(clip)
	_enemy_swing_delay = maxf(length * 0.30, 0.045)
	enemy_cooldown = maxf(1.7, length + _followup_duration(
		enemy_visual._fight_driver, _enemy_followups) + 0.45)
	_enemy_hit = length * 0.55


func _try_enemy_evade(distance: float) -> bool:
	if _enemy_evade_cooldown > 0.0 or game._visual.action_time <= 0.0:
		return false
	if distance > REACH + 0.5 or _rng.randf() > 0.3:
		return false
	var clip: String
	var followups: Array[String] = []
	var is_guard := false
	var choice := _rng.randi_range(0, 2)
	match choice:
		0:
			clip = FightLibrary.SWORD_BLOCK
			followups.append(FightLibrary.IDLE_SHIELD_LOOP)
			is_guard = true
		1:
			clip = FightLibrary.SLIDE_START
			followups.append(FightLibrary.SLIDE_LOOP)
			followups.append(FightLibrary.SLIDE_EXIT)
		_:
			clip = FightLibrary.NINJA_JUMP_START
			followups.append(FightLibrary.NINJA_JUMP_IDLE_LOOP)
			followups.append(FightLibrary.NINJA_JUMP_LAND)
	var length: float = enemy_visual.play_fight(clip)
	if length <= 0.0:
		return false
	_enemy_followups = _valid_followups(enemy_visual._fight_driver, followups)
	_enemy_guarding = is_guard
	var evade_duration := length + _followup_duration(
		enemy_visual._fight_driver, _enemy_followups)
	_enemy_invulnerable = evade_duration
	_enemy_evade_cooldown = 2.2
	enemy_cooldown = maxf(enemy_cooldown, evade_duration + 0.25)
	_enemy_hit = -1.0
	if is_guard:
		combat_fx.call("spawn_guard", enemy_visual.global_position + Vector3.UP * 1.05,
			Color(0.50, 0.83, 1.0), "GUARD")
	else:
		combat_fx.call("spawn_dodge", enemy_visual.global_position, Color(0.56, 0.86, 1.0))
	return true


func _physics_process(delta: float) -> void:
	_time += delta
	artifact.position.y = Shape.HEIGHT + 1.8 + sin(_time * 1.8) * 0.16
	artifact.rotation.y += delta * 0.7
	artifact.visible = game.inside_arena and not active and not finishing
	prompt.visible = not active and not finishing and nearby() and not game._graphics_drawer.visible
	if (active or finishing) and not game.inside_arena:
		reset()
		return
	if finishing:
		_finish_time -= delta
		if _finish_time <= 0.0:
			reset()
		return
	if not active or game._graphics_drawer.visible:
		return

	player_cooldown = maxf(0.0, player_cooldown - delta)
	enemy_cooldown = maxf(0.0, enemy_cooldown - delta)
	_enemy_invulnerable = maxf(0.0, _enemy_invulnerable - delta)
	_player_invulnerable = maxf(0.0, _player_invulnerable - delta)
	_enemy_dash_cooldown = maxf(0.0, _enemy_dash_cooldown - delta)
	_enemy_evade_cooldown = maxf(0.0, _enemy_evade_cooldown - delta)
	if _time - _last_player_attack > COMBO_WINDOW:
		_player_combo = 0

	_advance_player_followup()
	_advance_enemy_followup()
	if _player_swing_delay >= 0.0:
		_player_swing_delay = maxf(0.0, _player_swing_delay - delta)
		if _player_swing_delay == 0.0:
			combat_fx.call("play_swing", game._visual.global_position,
				enemy.global_position, _player_attack_tint,
				1.34 if _player_damage >= 35 else 1.0)
			_player_swing_delay = -1.0
	if _enemy_swing_delay >= 0.0 and is_instance_valid(enemy_visual):
		_enemy_swing_delay = maxf(0.0, _enemy_swing_delay - delta)
		if _enemy_swing_delay == 0.0:
			combat_fx.call("play_swing", enemy_visual.global_position,
				game._visual.global_position, _enemy_attack_tint, 1.0)
			_enemy_swing_delay = -1.0
	if _combo_hits > 0 and _time - _last_combo_hit > COMBO_WINDOW:
		_combo_hits = 0
		if _callout_time <= 0.0:
			combat_callout.hide()
	if _callout_time > 0.0:
		_callout_time = maxf(0.0, _callout_time - delta)
		if _callout_time == 0.0 and _combo_hits == 0:
			combat_callout.hide()

	var direction: Vector3 = game._player.position - enemy.position
	var distance := Vector2(direction.x, direction.z).length()
	enemy_visual.rotation.y = atan2(-direction.x, -direction.z)
	if _enemy_dashing and enemy_visual.action_time <= 0.0:
		_enemy_dashing = false
	if distance > 4.5 and _enemy_dash_cooldown <= 0.0 \
			and enemy_visual.action_time <= 0.0:
		var dash_clip := FightLibrary.SWORD_DASH
		var dash_followups: Array[String] = []
		if _enemy_zombie_style:
			dash_clip = FightLibrary.SLIDE_START
			dash_followups.append(FightLibrary.SLIDE_LOOP)
			dash_followups.append(FightLibrary.SLIDE_EXIT)
		elif _rng.randf() < 0.5:
			dash_clip = FightLibrary.SHIELD_DASH
		var dash_length: float = enemy_visual.play_fight(dash_clip)
		if dash_length > 0.0:
			_enemy_followups = _valid_followups(enemy_visual._fight_driver, dash_followups)
			_enemy_dashing = true
			_enemy_dash_cooldown = 3.0
			combat_fx.call("spawn_dodge", enemy_visual.global_position,
				_attack_tint(dash_clip))

	var can_move := distance > 1.9 and _enemy_hit < 0.0 \
			and (enemy_visual.action_time <= 0.0 or _enemy_dashing)
	var move_speed := 2.7
	if _enemy_dashing:
		move_speed = 4.2
	var velocity := direction.normalized() * move_speed if can_move else Vector3.ZERO
	enemy.velocity.x = velocity.x
	enemy.velocity.z = velocity.z
	enemy.velocity.y = 0.0 if enemy.is_on_floor() else enemy.velocity.y - 24.0 * delta
	enemy.move_and_slide()
	var visual_speed := Vector2(velocity.x, velocity.z).length()
	if _enemy_zombie_style:
		if enemy_visual.action_time <= 0.0:
			var desired_loop := FightLibrary.ZOMBIE_WALK_LOOP if can_move \
				else FightLibrary.ZOMBIE_IDLE_LOOP
			if not enemy_visual.fight_loop or _enemy_locomotion_clip != desired_loop:
				if enemy_visual.play_fight_loop(desired_loop):
					_enemy_locomotion_clip = desired_loop
	else:
		if enemy_visual.action_time > 0.0:
			visual_speed = 0.0
		enemy_visual.update_motion(visual_speed)

	if distance <= REACH and enemy_cooldown <= 0.0 and enemy_visual.action_time <= 0.0:
		if not _try_enemy_evade(distance):
			_start_enemy_attack(_choose_enemy_attack())
	elif distance <= 7.5 and enemy_cooldown <= 0.0 \
			and enemy_visual.action_time <= 0.0 and _rng.randf() < 0.2:
		_start_enemy_attack(FightLibrary.OVERHAND_THROW)

	if _player_hit >= 0.0:
		_player_hit -= delta
		if _player_hit < 0.0:
			if distance <= _player_hit_range:
				var impact_point := enemy_visual.global_position + Vector3.UP * 1.05
				if _enemy_invulnerable > 0.0:
					var evade_text := "GUARD" if _enemy_guarding else "DODGE"
					combat_fx.call("spawn_impact", impact_point, _player_attack_tint,
						0, false, evade_text)
				else:
					var damage := _player_damage
					var reaction := FightLibrary.HIT_KNOCKBACK
					_enemy_followups.clear()
					_enemy_dashing = false
					if _enemy_guarding:
						damage = maxi(1, int(_player_damage * 0.5))
						reaction = FightLibrary.IDLE_SHIELD_BREAK
						_enemy_guarding = false
						combat_fx.call("spawn_impact", impact_point,
							Color(0.66, 0.86, 1.0), damage, false, "GUARD BREAK")
						game._orbit.combat_shake(0.055, 0.10)
					else:
						if _player_damage >= 35 and enemy_hp > 0:
							_enemy_followups.append(FightLibrary.LAY_TO_IDLE)
						if _time - _last_combo_hit <= COMBO_WINDOW:
							_combo_hits += 1
						else:
							_combo_hits = 1
						_last_combo_hit = _time
						combat_fx.call("spawn_impact", impact_point,
							_player_attack_tint, damage, _player_damage >= 35)
						_show_combat_callout("COMBO ×%d" % _combo_hits,
							_player_attack_tint)
						game._orbit.combat_shake(
							0.11 if _player_damage >= 35 else 0.065,
							0.17 if _player_damage >= 35 else 0.11)
					enemy_hp = maxi(0, enemy_hp - damage)
					enemy_visual.play_fight(reaction)
					_enemy_swing_delay = -1.0
				_enemy_hit = -1.0
			_player_hit = -1.0

	if _enemy_hit >= 0.0:
		_enemy_hit -= delta
		if _enemy_hit < 0.0:
			if distance <= _enemy_attack_range:
				if _player_invulnerable <= 0.0:
					player_hp = maxi(0, player_hp - _enemy_damage)
					game._visual.play_fight(FightLibrary.HIT_KNOCKBACK)
					_player_followups.clear()
					_player_swing_delay = -1.0
					combat_fx.call("spawn_impact",
						game._visual.global_position + Vector3.UP * 1.05,
						_enemy_attack_tint, _enemy_damage, _enemy_damage >= 20)
					game._orbit.combat_shake(0.075, 0.13)
				else:
					combat_fx.call("spawn_guard",
						game._visual.global_position + Vector3.UP * 1.05,
						Color(0.55, 0.94, 1.0), "DODGE")
			_enemy_hit = -1.0

	_update_health_bars()
	if enemy_hp == 0 or player_hp == 0:
		finishing = true
		_finish_time = 2.0
		_player_hit = -1.0
		_enemy_hit = -1.0
		_player_followups.clear()
		_enemy_followups.clear()
		status.text = "Tantangan selesai!" if enemy_hp == 0 else "Coba lagi — dekati artefak"
		enemy_hud.hide()
		player_hud.hide()
		style_button.hide()
		evade_button.hide()
		if enemy_hp == 0:
			enemy_visual.play_fight(FightLibrary.HIT_KNOCKBACK)
			combat_fx.call("spawn_impact",
				enemy_visual.global_position + Vector3.UP * 1.1,
				Color(1.0, 0.79, 0.35), 0, true, "FINISH!")
			game._orbit.combat_shake(0.15, 0.24)
			_show_combat_callout("FINISH!", Color(1.0, 0.83, 0.43))
		else:
			game._visual.play_fight(FightLibrary.HIT_KNOCKBACK)
			_show_combat_callout("KNOCKED OUT", Color(1.0, 0.53, 0.56))


func movement_locked() -> bool:
	return active and (finishing or game._visual.action_time > 0)


func reset() -> void:
	active = false
	finishing = false
	_player_hit = -1.0
	_enemy_hit = -1.0
	_player_swing_delay = -1.0
	_enemy_swing_delay = -1.0
	_combo_hits = 0
	_callout_time = 0.0
	combat_callout.hide()
	combat_fx.call("clear")
	_player_combo = 0
	_last_player_attack = _time - COMBO_WINDOW - 1.0
	_player_hit_range = REACH
	_enemy_attack_range = REACH
	_player_invulnerable = 0.0
	_enemy_invulnerable = 0.0
	_player_followups.clear()
	_enemy_followups.clear()
	_enemy_guarding = false
	_enemy_zombie_style = false
	_enemy_locomotion_clip = ""
	_enemy_dashing = false
	if is_instance_valid(enemy):
		enemy.queue_free()
	enemy = null
	enemy_visual = null
	game._visual.cancel_fight()
	game._visual.set_fight_sword(false)
	sword_mode = false
	enemy_hud.hide()
	player_hud.hide()
	style_button.hide()
	evade_button.hide()
