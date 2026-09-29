extends Node3D
## Deterministic decoration across the island, only 7x7 local cells instantiated.

const Island = preload("res://src/game/island.gd")
const Library = preload("res://src/game/world/nature_library.gd")
const TILE := 40.0
const RADIUS := 3
const MAX_TILES := 49
const TREE_ATTEMPTS := 6
const DETAIL_ATTEMPTS := 12

var island: Island
var player: Node3D
var tiles: Dictionary[Vector2i, Node3D] = {}
var _center := Vector2i(9999, 9999)
var _pending: Array[Vector2i] = []


func _process(_delta: float) -> void:
	if player == null or island == null:
		return
	var center := Vector2i(floori(player.position.x / TILE), floori(player.position.z / TILE))
	if center != _center:
		_recenter(center)
	if not _pending.is_empty():
		_build_tile(_pending.pop_front())


func _recenter(center: Vector2i) -> void:
	_center = center
	_pending.clear()
	for key in tiles.keys():
		if maxi(absi(key.x - center.x), absi(key.y - center.y)) > RADIUS:
			tiles[key].queue_free()
			tiles.erase(key)
	for z in range(center.y - RADIUS, center.y + RADIUS + 1):
		for x in range(center.x - RADIUS, center.x + RADIUS + 1):
			var key := Vector2i(x, z)
			if not tiles.has(key):
				_pending.append(key)
	_pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(center) < b.distance_squared_to(center))


func can_place(point: Vector2, tree: bool) -> bool:
	if point.length() > 405 or absf(point.x) > 440 or absf(point.y) > 440:
		return false
	var height := island.surface_height(point.x, point.y)
	if height < 5.5:
		return false
	if absf(point.y) < 345 and Island.road_distance(point.x, point.y) < (17 if tree else 14):
		return false
	var gradient := Vector2(island.surface_height(point.x + 1, point.y)
		- island.surface_height(point.x - 1, point.y),
		island.surface_height(point.x, point.y + 1)
		- island.surface_height(point.x, point.y - 1)) * 0.5
	if gradient.length() > 0.40:
		return false
	for rock in island.rock_clearances:
		if point.distance_to(Vector2(rock.x, rock.z)) < rock.y + 2.0:
			return false
	return true


func placements_for(key: Vector2i) -> Array[Dictionary]:
	var random := RandomNumberGenerator.new()
	random.seed = hash(key) + 71037
	var result: Array[Dictionary] = []
	for index in range(TREE_ATTEMPTS + DETAIL_ATTEMPTS):
		var tree := index < TREE_ATTEMPTS
		var point := Vector2(key.x * TILE, key.y * TILE)
		point += Vector2(random.randf_range(4, TILE - 4), random.randf_range(4, TILE - 4))
		# Open meadows alternate with denser groves; no regular grid of trees.
		var grove := sin(point.x * 0.027) * cos(point.y * 0.033)
		if tree and random.randf() > 0.58 + grove * 0.25:
			continue
		if not can_place(point, tree):
			continue
		var too_close := false
		for item in result:
			var old: Vector3 = item["position"]
			if point.distance_to(Vector2(old.x, old.z)) < (5.5 if tree else 1.8):
				too_close = true
		if too_close:
			continue
		var kind := random.randi_range(0, 2) if tree else random.randi_range(3, 9)
		var scale_factor := random.randf_range(0.80, 1.15)
		if kind == 5:
			scale_factor *= 0.16 # Archived fern is nine metres wide at authored scale.
		elif kind == 6:
			scale_factor *= 0.30
		elif kind == 3 or kind == 4:
			scale_factor *= 0.75
		var height := island.surface_height(point.x, point.y)
		result.append({"asset": Library.ASSETS[kind], "tree": tree,
			"solid": tree or kind == 7 or kind == 8,
			"position": Vector3(point.x, height, point.y),
			"yaw": random.randf_range(0, TAU), "scale": scale_factor})
	return result


func _build_tile(key: Vector2i) -> void:
	var tile := Node3D.new()
	tile.name = "Nature_%d_%d" % [key.x, key.y]
	tile.position = Vector3(key.x * TILE, 0, key.y * TILE)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	tile.add_child(body)
	var groups: Dictionary[String, Array] = {}
	for item in placements_for(key):
		var asset: String = item["asset"]
		if not groups.has(asset):
			groups[asset] = []
		var location: Vector3 = item["position"] - tile.position
		var size: float = item["scale"]
		var pose := Transform3D(Basis(Vector3.UP, item["yaw"]).scaled(Vector3.ONE * size),
			location)
		groups[asset].append(pose)
		if item["solid"]:
			_add_collision(body, location, size, item["tree"])
	for asset in groups:
		var placements: Array[Transform3D] = []
		placements.assign(groups[asset])
		var tree := Library.ASSETS.find(asset) < 3
		Library.add_batch(tile, asset, placements, 110 if tree else 65)
	add_child(tile)
	tiles[key] = tile


func _add_collision(body: StaticBody3D, point: Vector3, size: float, tree: bool) -> void:
	var collision := CollisionShape3D.new()
	if tree:
		var shape := CylinderShape3D.new()
		shape.radius = 0.28 * size
		shape.height = 3.0 * size
		collision.shape = shape
		collision.position = point + Vector3(0, 1.5 * size, 0)
	else:
		var shape := SphereShape3D.new()
		shape.radius = 0.85 * size
		collision.shape = shape
		collision.position = point + Vector3(0, 0.75 * size, 0)
	body.add_child(collision)
