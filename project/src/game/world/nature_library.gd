extends RefCounted
## Actual archived glTF meshes/materials, shared by streamed spatial batches.

const ASSETS: Array[String] = ["CommonTree_1", "CommonTree_3", "Pine_1",
	"Bush_Common", "Bush_Common_Flowers", "Fern_1", "Flower_3_Group",
	"Rock_Medium_1", "Rock_Medium_2", "Pebble_Round_1", "RockPath_Round_Wide"]
static var _parts: Dictionary[String, Array] = {}


static func parts(asset: String) -> Array:
	if _parts.has(asset):
		return _parts[asset]
	var scene := load("res://assets/nature/" + asset + ".gltf") as PackedScene
	var root := scene.instantiate() as Node3D
	var result: Array = []
	_collect(root, Transform3D.IDENTITY, result)
	root.free()
	_parts[asset] = result
	return result


static func _collect(node: Node3D, parent: Transform3D, result: Array) -> void:
	var pose := parent * node.transform
	if node is MeshInstance3D:
		var visual := node as MeshInstance3D
		result.append({"mesh": visual.mesh, "pose": pose})
	for child in node.get_children():
		if child is Node3D:
			_collect(child, pose, result)


static func add_batch(parent: Node3D, asset: String, placements: Array[Transform3D],
		reach: float) -> void:
	if placements.is_empty():
		return
	for part: Dictionary in parts(asset):
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = part["mesh"]
		multi.instance_count = placements.size()
		for index in range(placements.size()):
			multi.set_instance_transform(index, placements[index] * part["pose"])
		var batch := MultiMeshInstance3D.new()
		batch.name = asset
		batch.multimesh = multi
		batch.lod_bias = 0.55
		batch.visibility_range_end = reach
		batch.visibility_range_end_margin = 8
		# No transparent distance fade (alpha-cutout foliage stays depth-writing).
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(batch)
