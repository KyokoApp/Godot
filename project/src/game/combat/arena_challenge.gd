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
var enemy: CharacterBody3D
var enemy_visual: Character
var prompt: Rune
var hud_panel: PanelContainer
var status: Label
var player_hp_bar: ProgressBar
var enemy_hp_bar: ProgressBar
var player_hp_value: Label
var enemy_hp_value: Label
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
	hud_panel = PanelContainer.new()
	hud_panel.name = "ChallengeHUD"
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.035, 0.07, 0.9)
	panel_style.border_color = Color("83dce8")
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(12)
	panel_style.content_margin_left = 14
	panel_style.content_margin_right = 14
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 8
	hud_panel.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(hud_panel)
	hud_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hud_panel.position = Vector2(-230, 24)
	hud_panel.size = Vector2(460, 128)
	hud_panel.custom_minimum_size = hud_panel.size
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	hud_panel.add_child(content)
	status = Label.new()
	status.text = "TANTANGAN ARENA"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 14)
	status.add_theme_color_override("font_color", Color("f1dba9"))
	content.add_child(status)
	content.add_child(_make_hp_row("KAMU", Color("70dfce"), true))
	content.add_child(_make_hp_row("MANNEQUIN", Color("f1a77e"), false))
	prompt.hide()
	hud_panel.hide()
	_update_health_bars()


func _make_hp_row(caption: String, fill_color: Color, player: bool) -> VBoxContainer:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	var heading := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = caption
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color("e4e9f3"))
	heading.add_child(name_label)
	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 11)
	value_label.add_theme_color_override("font_color", Color("f3f5fa"))
	heading.add_child(value_label)
	row.add_child(heading)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = MAX_HP
	bar.value = MAX_HP
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.11, 0.13, 0.19, 1.0)
	background.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(5)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	if player:
		player_hp_bar = bar
		player_hp_value = value_label
	else:
		enemy_hp_bar = bar
		enemy_hp_value = value_label
	return row


func _update_health_bars() -> void:
	if player_hp_bar == null or enemy_hp_bar == null:
		return
	player_hp_bar.value = player_hp
	enemy_hp_bar.value = enemy_hp
	player_hp_value.text = "%d / %d" % [player_hp, MAX_HP]
	enemy_hp_value.text = "%d / %d" % [enemy_hp, MAX_HP]


func nearby() -> bool:
	return game.inside_arena and game._player.position.distance_to(
		Vector3(Shape.CENTER.x, Shape.HEIGHT, Shape.CENTER.y)) < 3.5


func start() -> void:
	if active or finishing or not nearby() or game._graphics_drawer.visible:
		return
	if not game._visual.prepare_fight():
		return
	active = true
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
	status.text = "TANTANGAN ARENA"
	hud_panel.show()
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


func attack() -> void:
	if not active or finishing or player_cooldown > 0 or game._graphics_drawer.visible:
		return
	var direction: Vector3 = enemy.position - game._player.position
	game._visual.rotation.y = atan2(-direction.x, -direction.z)
	var length: float = game._visual.play_fight(FightLibrary.PUNCH)
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
		var length := enemy_visual.play_fight(FightLibrary.PUNCH)
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
	hud_panel.hide()
