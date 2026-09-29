extends Node3D
## One opt-in, non-gory sparring encounter. No enemy outside the challenge.
const Character = preload("res://src/game/mannequin.gd")
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
var status: Label
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
	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_shadow_color", Color.BLACK)
	status.add_theme_constant_override("shadow_offset_y", 2)
	layer.add_child(status)
	status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	status.position = Vector2(-230, 32)
	status.size = Vector2(460, 70)
	prompt.hide()
	status.hide()


func nearby() -> bool:
	return game.inside_arena and game._player.position.distance_to(
		Vector3(Shape.CENTER.x, Shape.HEIGHT, Shape.CENTER.y)) < 3.5


func start() -> void:
	if active or finishing or not nearby() or game._graphics_drawer.visible:
		return
	if not Character.FightLibrary.install(game._visual.animation, game._visual.source_skeleton):
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
	Character.FightLibrary.install(enemy_visual.animation, enemy_visual.source_skeleton)
	artifact.hide()
	prompt.hide()
	status.show()


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
	var length: float = game._visual.play_fight("fight/Melee_Hook")
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
		var length := enemy_visual.play_fight("fight/Melee_Hook")
		enemy_cooldown = maxf(1.7, length + 0.5)
		_enemy_hit = length * 0.55
	if _player_hit >= 0:
		_player_hit -= delta
		if _player_hit < 0 and distance <= REACH:
			enemy_hp = maxi(0, enemy_hp - 25)
			enemy_visual.play_fight("fight/Hit_Knockback")
			_enemy_hit = -1.0
	if _enemy_hit >= 0:
		_enemy_hit -= delta
		if _enemy_hit < 0 and distance <= REACH:
			player_hp = maxi(0, player_hp - 15)
			game._visual.play_fight("fight/Hit_Knockback")
			_player_hit = -1.0
	status.text = "TANTANGAN ARENA\nKamu  %d / 100     •     Mannequin  %d / 100" % [
		player_hp, enemy_hp]
	if enemy_hp == 0 or player_hp == 0:
		finishing = true
		_finish_time = 2.0
		_player_hit = -1
		_enemy_hit = -1
		status.text = "Tantangan selesai!" if enemy_hp == 0 else "Coba lagi — dekati artefak"
		if enemy_hp == 0:
			enemy_visual.play_fight("Death01")
		else:
			game._visual.play_fight("Death01")


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
	status.hide()
