extends RefCounted
## Render resource asli: material tanah, rumput MultiMesh, avatar ber-skinning,
## lapisan tubuh atas, tapak api, aura cepat, sinar matahari, dan contact shadow.

const Field = preload("res://src/game/world/field.gd")
const Character = preload("res://src/game/mannequin.gd")
const Spirit = preload("res://src/game/legacy_spirit/spirit_visual.gd")
const Projectile = preload("res://src/game/fire_projectile.gd")
const Burst = preload("res://src/game/fire_burst.gd")
const FootFire = preload("res://src/game/foot_fire/foot_fire_trail.gd")
const SpeedAura = preload("res://src/game/speed/speed_aura.gd")
const SunRays = preload("res://src/game/god_rays/sun_rays.gd")
const ContactShadows = preload("res://src/game/god_rays/contact_shadows.gd")
const STAGES := 14


static func populate(stage: int, world: Node3D, game: Node3D) -> void:
	stage = (stage + 1) % STAGES
	if stage == 0:
		_terrain(world, game)
	elif stage == 1 or stage == 2:
		_grass(world, game, stage == 2)
	elif stage <= 6:
		_avatar(world, stage)
	elif stage == 7:
		_spirit(world)
	elif stage == 8:
		_burst(world)
	elif stage == 9:
		_foot_fire(world)
	elif stage == 10 or stage == 11:
		_speed(world, game, stage == 11)
	elif stage == 12:
		_rays(world)
	else:
		_field_ground(world, game)


static func _terrain(world: Node3D, game: Node3D) -> void:
	# Bidang memakai material padang asli: shader, tekstur, dan warna yang sama.
	_field_ground(world, game)


static func _field_ground(world: Node3D, game: Node3D) -> void:
	var visual := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	visual.mesh = plane
	var field: Node3D = game.get("_field")
	if field != null:
		visual.material_override = field.get("_material") as Material
	world.add_child(visual)


static func _grass(world: Node3D, game: Node3D, far: bool) -> void:
	var field: Node3D = game.get("_grass")
	if field == null:
		return
	var mesh: Mesh = field.get("_far_mesh") if far else field.get("_mesh")
	_add_grass(world, mesh, field.get("_material"), Vector3.ZERO)
	if far:
		var distant: Node3D = field.get("distant")
		_add_grass(world, distant.get("_mesh"), distant.get("_material"), Vector3(-25, 0, 0))


static func _avatar(world: Node3D, stage: int) -> void:
	var character := Character.new()
	world.add_child(character)
	if stage == 3:
		character.set_locomotion("Idle_Loop", 1.0)
	elif stage == 4:
		character.set_locomotion("Walk_Loop", 1.2)
	elif stage == 5:
		character.set_locomotion("Jog_Fwd_Loop", 1.0)
		character.start_cast()
		character.cast_layer._physics_process(0.1)
		character.cast_layer._process_modification_with_delta(0.0)
	else:
		character.play_action("Sword_Regular_Combo")
		character.animation.advance(0.35)


static func _spirit(world: Node3D) -> void:
	var spirit := Spirit.new()
	world.add_child(spirit)
	spirit.scale = Vector3.ONE * 2
	spirit.set_process(false)
	var shot := Projectile.new()
	shot.position = Vector3(1, 1, 0)
	world.add_child(shot)
	shot.set_physics_process(false)
	shot.velocity = Vector3(12, 0, 0)


static func _burst(world: Node3D) -> void:
	var burst := Burst.new()
	world.add_child(burst)
	burst.set_process(false)
	burst.age = 0.22
	burst._update_visuals()


static func _foot_fire(world: Node3D) -> void:
	var fire := FootFire.new()
	world.add_child(fire)
	fire.add_stamp(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 4),
		Vector3(0, 0.5, 0)))
	fire.set_physics_process(false)


static func _speed(world: Node3D, game: Node3D, with_ghosts: bool) -> void:
	var character := Character.new()
	world.add_child(character)
	character.set_locomotion("Sprint_Loop", 1.0)
	var trail := SpeedAura.new()
	trail.character = character
	var environment := game.get_node("DuskEnvironment") as WorldEnvironment
	trail.environment = environment.environment
	world.add_child(trail)
	trail.update_motion(0.11, 15, with_ghosts)
	if with_ghosts:
		for _sample in range(24):
			character.position.z += 0.08
			trail.update_motion(1.0 / 60.0, 15, true)
	character.hide()


static func _rays(world: Node3D) -> void:
	var rays := SunRays.new()
	world.add_child(rays)
	rays.set_process(false)
	rays.visible = true
	rays.material_override.set_shader_parameter("source_uv", Vector2(0.5, 0.5))
	rays.material_override.set_shader_parameter("strength", 0.16)
	# Contact shadow memakai shader baru (satu layar penuh, 14 sampel): panaskan
	# di sini supaya tidak ada sekali jeda saat efek pertama kali tampil.
	var contact := ContactShadows.new()
	world.add_child(contact)
	contact.set_process(false)
	contact.visible = true


static func _add_grass(world: Node3D, mesh: Mesh, source: ShaderMaterial,
		player: Vector3) -> void:
	var material := source.duplicate() as ShaderMaterial
	material.set_shader_parameter("player_position", player)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = mesh
	multi.instance_count = 4
	for index in range(4):
		multi.set_instance_transform(index, Transform3D(Basis.IDENTITY,
			Vector3((index - 1.5) * 0.5, 0, 0)))
		multi.set_instance_custom_data(index, Color(index % 2, 0, 0, 0))
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = multi
	batch.material_override = material
	world.add_child(batch)
