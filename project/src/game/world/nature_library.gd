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
		result.append({"mesh": _mobile_mesh(visual.mesh), "pose": pose})
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


static func _mobile_mesh(source: Mesh) -> Mesh:
	var mesh := source.duplicate() as ArrayMesh
	for index in range(mesh.get_surface_count()):
		var original := mesh.surface_get_material(index) as StandardMaterial3D
		if original == null:
			continue
		var material := original.duplicate() as StandardMaterial3D
		# Preserve original textures/cutout/colors; simplify lighting, not geometry.
		material.normal_enabled = false
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
		material.roughness = 1.0
		mesh.surface_set_material(index, material)
	return mesh
