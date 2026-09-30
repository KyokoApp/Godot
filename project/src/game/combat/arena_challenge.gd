extends Node3D
## One opt-in, non-gory sparring encounter. No enemy outside the challenge.
const Character = preload("res://src/game/mannequin.gd")
const FightLibrary = preload("res://src/game/combat/fight_library.gd")
const Shape = preload("res://src/game/arena/arena_shape.gd")
const Rune = preload("res://src/game/ui/rune_button.gd")
const REACH := 2.5
const MAX_HP := 100
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
var enemy_hud: Control
var player_hud: PanelContainer
var status: Label
var player_hp_bar: ProgressBar
var enemy_hp_bar: ProgressBar
var player_hp_value: Label
var artifact: Node3D
var player_cooldown := 0.0
var enemy_cooldown := 1.0
var _player_hit := -1.0
var _enemy_hit := -1.0
var _finish_time := 0.0
var _time := 0.0


func _ready() -> void:
	name = "ArenaChallenge"
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
	prompt.hide()
	enemy_hud.hide()
	player_hud.hide()
	style_button.hide()
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
	artifact.hide()
	prompt.hide()
	status.text = "MANNEQUIN"
	enemy_hud.show()
	player_hud.show()
	style_button.show()
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


func attack() -> void:
	if not active or finishing or player_cooldown > 0 or game._graphics_drawer.visible:
		return
	var direction: Vector3 = enemy.position - game._player.position
	game._visual.rotation.y = atan2(-direction.x, -direction.z)
	var clip := FightLibrary.SWORD if sword_mode else FightLibrary.MELEE
	var length: float = game._visual.play_fight(clip)
	if length <= 0:
		return
	player_cooldown = maxf(length + 0.2, 0.8)
	_player_hit = length * 0.45


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
		if _finish_time <= 0:
			reset()
		return
	if not active:
		return
	if game._graphics_drawer.visible:
		return
	player_cooldown = maxf(0, player_cooldown - delta)
	enemy_cooldown = maxf(0, enemy_cooldown - delta)
	var direction: Vector3 = game._player.position - enemy.position
	var distance := Vector2(direction.x, direction.z).length()
	enemy_visual.rotation.y = atan2(-direction.x, -direction.z)
	var moving := distance > 1.9 and _enemy_hit < 0 and enemy_visual.action_time <= 0
	var velocity := direction.normalized() * 2.7 if moving else Vector3.ZERO
	enemy.velocity.x = velocity.x
	enemy.velocity.z = velocity.z
	enemy.velocity.y = 0 if enemy.is_on_floor() else enemy.velocity.y - 24 * delta
	enemy.move_and_slide()
	enemy_visual.update_motion(Vector2(velocity.x, velocity.z).length())
	if distance <= REACH and enemy_cooldown == 0:
		var length := enemy_visual.play_fight(FightLibrary.MELEE)
		enemy_cooldown = maxf(1.7, length + 0.5)
		_enemy_hit = length * 0.55
	if _player_hit >= 0:
		_player_hit -= delta
		if _player_hit < 0 and distance <= REACH:
			enemy_hp = maxi(0, enemy_hp - 25)
			enemy_visual.play_fight(FightLibrary.HIT)
			_enemy_hit = -1.0
	if _enemy_hit >= 0:
		_enemy_hit -= delta
		if _enemy_hit < 0 and distance <= REACH:
			player_hp = maxi(0, player_hp - 15)
			game._visual.play_fight(FightLibrary.HIT)
			_player_hit = -1.0
	_update_health_bars()
	if enemy_hp == 0 or player_hp == 0:
		finishing = true
		_finish_time = 2.0
		_player_hit = -1
		_enemy_hit = -1
		status.text = "Tantangan selesai!" if enemy_hp == 0 else "Coba lagi — dekati artefak"
		enemy_hud.hide()
		player_hud.hide()
		style_button.hide()
		if enemy_hp == 0:
			enemy_visual.play_fight(FightLibrary.HIT)
		else:
			game._visual.play_fight(FightLibrary.HIT)


func movement_locked() -> bool:
	return active and (finishing or game._visual.action_time > 0)


func reset() -> void:
	active = false
	finishing = false
	_player_hit = -1.0
	_enemy_hit = -1.0
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
