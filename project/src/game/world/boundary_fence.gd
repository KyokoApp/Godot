extends Node3D
## Pagar kayu di keliling padang 100 m: penanda skala + dinding collision tipis.
## Hanya memakai mesh kotak prosedural, jadi tidak menambah aset atau tekstur.

const Field = preload("res://src/game/world/field.gd")
const POST_SPACING := 5.0
const POST_SIZE := Vector3(0.11, 1.05, 0.11)
const RAIL_SIZE := Vector3(100.0, 0.07, 0.05)
const WALL_THICKNESS := 0.7
const WALL_HEIGHT := 2.2
const WOOD := Color("8a6a49")
const WOOD_DARK := Color("6b5138")

var _post_mesh: BoxMesh


func _ready() -> void:
	name = "BoundaryFence"
	_post_mesh = BoxMesh.new()
	_post_mesh.size = POST_SIZE
	var posts := MultiMesh.new()
	posts.transform_format = MultiMesh.TRANSFORM_3D
	posts.mesh = _post_mesh
	posts.instance_count = _post_count() * 4
	var index := 0
	var limit := Field.HALF
	for step in range(_post_count()):
		var along := -limit + step * POST_SPACING
		for side in range(4):
			var corner := along
			var position_3d := _post_position(corner, side)
			position_3d.y = _ground_height(position_3d.x, position_3d.z)
			posts.set_instance_transform(index, Transform3D(Basis.IDENTITY, position_3d))
			index += 1
	posts.instance_count = index
	var post_visual := MultiMeshInstance3D.new()
	post_visual.name = "Posts"
	post_visual.multimesh = posts
	post_visual.material_override = _wood_material(WOOD)
	post_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(post_visual)
	_build_rails()
	_build_walls(limit)


func _post_count() -> int:
	return int(round(Field.SIZE / POST_SPACING)) + 1


func _post_position(along: float, side: int) -> Vector3:
	var limit := Field.HALF
	match side:
		0:
			return Vector3(along, 0, -limit)
		1:
			return Vector3(along, 0, limit)
		2:
			return Vector3(-limit, 0, along)
		_:
			return Vector3(limit, 0, along)


func _ground_height(x: float, z: float) -> float:
	return Field.terrain_height(clampf(x, -Field.HALF, Field.HALF),
		clampf(z, -Field.HALF, Field.HALF)) + POST_SIZE.y * 0.5


func _build_rails() -> void:
	var mesh := BoxMesh.new()
	mesh.size = RAIL_SIZE
	var rails := MultiMesh.new()
	rails.transform_format = MultiMesh.TRANSFORM_3D
	rails.mesh = mesh
	rails.instance_count = 8
	var index := 0
	for side in range(4):
		for height in [0.42, 0.78]:
			var y := _rail_height(side, height)
			var basis := Basis(Vector3.UP, _rail_yaw(side))
			rails.set_instance_transform(index, Transform3D(basis, _rail_origin(side, y)))
			index += 1
	var visual := MultiMeshInstance3D.new()
	visual.name = "Rails"
	visual.multimesh = rails
	visual.material_override = _wood_material(WOOD_DARK)
	add_child(visual)


func _rail_yaw(side: int) -> float:
	return 0.0 if side < 2 else PI * 0.5


func _rail_height(side: int, height: float) -> float:
	var edge := -Field.HALF if side % 2 == 0 else Field.HALF
	var probe := Vector3(0, 0, edge) if side < 2 else Vector3(edge, 0, 0)
	return _ground_height(probe.x, probe.z) - POST_SIZE.y * 0.5 + height


func _rail_origin(side: int, y: float) -> Vector3:
	var limit := Field.HALF
	if side == 0:
		return Vector3(0, y, -limit)
	if side == 1:
		return Vector3(0, y, limit)
	return Vector3(-limit if side == 2 else limit, y, 0)


func _build_walls(limit: float) -> void:
	var body := StaticBody3D.new()
	body.name = "FenceCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	for side in range(4):
		var shape := BoxShape3D.new()
		shape.size = Vector3(Field.SIZE + WALL_THICKNESS, WALL_HEIGHT, WALL_THICKNESS)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		var offset := limit + WALL_THICKNESS * 0.5
		var y := _rail_height(side, 0.0) + WALL_HEIGHT * 0.5
		if side == 0:
			collision.position = Vector3(0, y, -offset)
		elif side == 1:
			collision.position = Vector3(0, y, offset)
		elif side == 2:
			collision.position = Vector3(-offset, y, 0)
			collision.rotation.y = PI * 0.5
		else:
			collision.position = Vector3(offset, y, 0)
			collision.rotation.y = PI * 0.5
		body.add_child(collision)
	add_child(body)


func _wood_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	material.metallic = 0.0
	return material
