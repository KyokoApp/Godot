extends Node3D
## Bekas pose beku mannequin: geometri sama, tanpa animasi/tekstur/bayangan.

const Character = preload("res://src/game/mannequin.gd")
const SHADER = preload("res://src/game/speed/afterimage.gdshader")
const INTERVAL := 0.10
const LIFETIME := 0.28
var character: Character
var emitted := 0
var ghosts: Array[Node3D] = []
var _skeletons: Array[Skeleton3D] = []
var _materials: Array[ShaderMaterial] = []
var _ages: Array[float] = []
var _meshes: Array[MeshInstance3D] = []
var _source: Skeleton3D
var _clock := 0.0
var _next := 0
var _pending := false
var _previous := Vector3.ZERO


func update_motion(delta: float, speed: float, boosted: bool) -> void:
	for index in range(ghosts.size()):
		_ages[index] += delta
		var life := maxf(0, 1.0 - _ages[index] / LIFETIME)
		_materials[index].set_shader_parameter("opacity", 0.26 * life * life)
		ghosts[index].visible = life > 0
	var position := character.global_position
	if position.distance_to(_previous) > 3.0:
		clear()
	_previous = position
	if not boosted or speed < 0.3:
		_pending = false
		_clock = 0
		return
	if _source == null:
		_rebuild()
	_clock += delta
	if _clock >= INTERVAL:
		_clock = fmod(_clock, INTERVAL)
		_pending = true


func clear() -> void:
	_pending = false
	_clock = 0
	for index in range(ghosts.size()):
		ghosts[index].hide()
		_ages[index] = LIFETIME


func _rebuild() -> void:
	for ghost in ghosts:
		ghost.queue_free()
	ghosts.clear()
	_skeletons.clear()
	_materials.clear()
	_ages.clear()
	_meshes.clear()
	_next = 0
	_source = character.skeleton
	# Godot emits this after all modifiers, before skin upload and pose restoration.
	# Unlike CastLayer's signal, it also fires during ordinary non-casting locomotion.
	var capture := _capture.bind(_source)
	if not _source.skeleton_updated.is_connected(capture):
		_source.skeleton_updated.connect(capture)
	for node in character.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.is_visible_in_tree():
			_meshes.append(mesh)
	for index in range(3):
		_build_ghost()


func _build_ghost() -> void:
	var ghost := Node3D.new()
	add_child(ghost)
	var skeleton := Skeleton3D.new()
	skeleton.name = "FrozenSkeleton"
	ghost.add_child(skeleton)
	for bone in range(_source.get_bone_count()):
		skeleton.add_bone(_source.get_bone_name(bone))
		skeleton.set_bone_parent(bone, _source.get_bone_parent(bone))
		skeleton.set_bone_rest(bone, _source.get_bone_rest(bone))
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("tint", Color("c5a0ee"))
	for source in _meshes:
		var mesh := MeshInstance3D.new()
		mesh.mesh = source.mesh
		mesh.skin = source.skin
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.lod_bias = 0.08
		mesh.extra_cull_margin = 0.4
		mesh.skeleton = NodePath("../FrozenSkeleton")
		ghost.add_child(mesh)
	ghost.hide()
	ghosts.append(ghost)
	_skeletons.append(skeleton)
	_materials.append(material)
	_ages.append(LIFETIME)


func _capture(source: Skeleton3D) -> void:
	if not _pending or source != _source:
		return
	_pending = false
	var ghost := ghosts[_next]
	ghost.global_transform = source.global_transform
	var skeleton := _skeletons[_next]
	for bone in range(source.get_bone_count()):
		skeleton.set_bone_pose_position(bone, source.get_bone_pose_position(bone))
		skeleton.set_bone_pose_rotation(bone, source.get_bone_pose_rotation(bone))
		skeleton.set_bone_pose_scale(bone, source.get_bone_pose_scale(bone))
	for index in range(_meshes.size()):
		var mesh := ghost.get_child(index + 1) as MeshInstance3D
		mesh.global_transform = _meshes[index].global_transform
	_ages[_next] = 0
	_materials[_next].set_shader_parameter("opacity", 0.26)
	ghost.show()
	_next = (_next + 1) % ghosts.size()
	emitted += 1
