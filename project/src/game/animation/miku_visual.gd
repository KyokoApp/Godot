extends RefCounted
## Native imported GLB with original base-color textures; no extra VRM plugin.

const KANNA_MODEL = preload("res://assets/characters/kanna/kanna.glb")
const MODEL = preload("res://assets/characters/miku/miku.glb")


static func create(parent: Node3D, source: Skeleton3D, kanna := false) -> Node3D:
	var scene: PackedScene = KANNA_MODEL if kanna else MODEL
	var model := scene.instantiate() as Node3D
	model.name = "Kanna" if kanna else "Miku"
	parent.add_child(model)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		model.queue_free()
		return null
	var source_height := _height(source, "Head", "foot_l", "foot_r")
	var target_height := _height(skeleton, "J_Bip_C_Head", "J_Bip_L_Foot", "J_Bip_R_Foot")
	if kanna:
		target_height = _height(skeleton, "DEF-Head", "DEF-Left ankle", "DEF-Right ankle")
	model.scale = Vector3.ONE * (source_height / maxf(target_height, 0.01))
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		# Skin/morph movement can exceed the T-pose bounds slightly.
		mesh.extra_cull_margin = 0.3
		for surface in range(mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original == null:
				continue
			var material := original.duplicate() as StandardMaterial3D
			material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			material.roughness = 1.0
			material.metallic = 0.0
			# Preserve MASK hair, use depth prepass only for originally BLEND face layers.
			if material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			mesh.set_surface_override_material(surface, material)
	return model


static func _height(skeleton: Skeleton3D, head: String, left: String, right: String) -> float:
	var top := skeleton.find_bone(head)
	var foot_l := skeleton.find_bone(left)
	var foot_r := skeleton.find_bone(right)
	if mini(top, mini(foot_l, foot_r)) < 0:
		return 1.0
	return skeleton.get_bone_global_rest(top).origin.y - (
		skeleton.get_bone_global_rest(foot_l).origin.y
		+ skeleton.get_bone_global_rest(foot_r).origin.y) * 0.5
