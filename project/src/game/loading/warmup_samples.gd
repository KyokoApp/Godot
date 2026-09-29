extends RefCounted
## Render real resources/layouts, including MultiMesh, skinning and GPU particles.

const Library = preload("res://src/game/world/nature_library.gd")
const Character = preload("res://src/game/mannequin.gd")
const Spirit = preload("res://src/game/legacy_spirit/spirit_visual.gd")
const Projectile = preload("res://src/game/fire_projectile.gd")
const Burst = preload("res://src/game/fire_burst.gd")
const WaterMaterial = preload("res://src/game/water/water_material.gd")
const FootFire = preload("res://src/game/foot_fire/foot_fire_trail.gd")
const STAGES := 21


static func populate(stage: int, world: Node3D, game: Node3D) -> void:
	# First warm character/grass/combat, then the optional scenery variants.
	stage = (stage + 11) % STAGES
	if stage < Library.ASSETS.size():
		var asset := Library.ASSETS[stage]
		var placements: Array[Transform3D] = [Transform3D.IDENTITY]
		Library.add_batch(world, asset, placements, 0)
		for child in world.get_children():
			if child is MultiMeshInstance3D:
				var bounds: AABB = child.multimesh.mesh.get_aabb()
				var height := maxf(bounds.size.y, maxf(bounds.size.x, bounds.size.z))
				child.scale = Vector3.ONE * (3.0 / maxf(height, 0.1))
				child.position = -bounds.get_center() * child.scale + Vector3(0, 1.5, 0)
	elif stage == 11:
		var character := Character.new()
		world.add_child(character)
		character.update_motion(5)
		character.start_cast()
	elif stage == 12:
		var field: Node3D = game.get("_grass")
		_add_grass(world, field.get("_mesh"), field.get("_material"), Vector3.ZERO)
		_add_grass(world, field.get("_far_mesh"), field.get("_material"), Vector3.ZERO)
		var distant: Node3D = field.get("distant")
		_add_grass(world, distant.get("_mesh"), distant.get("_material"), Vector3(-25, 0, 0))
	elif stage == 13:
		var spirit := Spirit.new()
		world.add_child(spirit)
		spirit.scale = Vector3.ONE * 2
		spirit.set_process(false)
		var shot := Projectile.new()
		shot.position = Vector3(1, 1, 0)
		world.add_child(shot)
		shot.set_physics_process(false)
		shot.velocity = Vector3(12, 0, 0)
	elif stage == 14:
		var burst := Burst.new()
		world.add_child(burst)
		burst.set_process(false)
		burst.age = 0.22
		burst._update_visuals()
	elif stage == 20:
		var fire := FootFire.new()
		world.add_child(fire)
		fire.add_stamp(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 4),
			Vector3(0, 0.5, 0)), "miku")
		fire.set_physics_process(false)
	elif stage >= 18:
		var character := Character.new()
		world.add_child(character)
		character.set_skin(Character.MIKU if stage == 18 else Character.KANNA)
		character.update_motion(5)
		character.start_cast()
	elif stage >= 16:
		var visual := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(6, 6)
		visual.mesh = plane
		var material := WaterMaterial.create()
		material.set_shader_parameter("ssr_enabled", stage == 17)
		visual.material_override = material
		visual.position.y = 0.2
		world.add_child(visual)
	else:
		# Root world continues rendering behind the opaque loading UI: sky, terrain,
		# sea, live character, current shadow/MSAA/scale settings, real viewport formats.
		var visual := MeshInstance3D.new()
		visual.mesh = PlaneMesh.new()
		var island: Node3D = game.get("_island")
		visual.material_override = island.get("_terrain_material")
		world.add_child(visual)


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
