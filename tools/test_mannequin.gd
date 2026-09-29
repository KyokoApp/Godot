extends SceneTree

const Character = preload("res://src/game/mannequin.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var character := Character.new()
	root.add_child(character)
	await process_frame
	for node in character.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var material := mesh.material_override as StandardMaterial3D
		_check(material != null and material.next_pass is ShaderMaterial,
			"Outline mannequin hilang")
	var animation := character.animation
	var skeleton := character.find_child("Skeleton3D", true, false) as Skeleton3D
	_check(animation != null and skeleton != null, "Rig/AnimationPlayer hilang")
	if animation == null or skeleton == null:
		quit(1)
		return
	for clip in [Character.IDLE, Character.WALK, Character.RUN]:
		_check(animation.has_animation(clip), "Klip hasil import hilang: " + clip)
		if not animation.has_animation(clip):
			continue
		animation.play(clip, 0.0)
		animation.advance(0.1)
		var poses: Array[Quaternion] = []
		for bone in range(skeleton.get_bone_count()):
			poses.append(skeleton.get_bone_pose_rotation(bone))
		animation.advance(0.3)
		var changed := false
		for bone in range(skeleton.get_bone_count()):
			if not poses[bone].is_equal_approx(skeleton.get_bone_pose_rotation(bone)):
				changed = true
		_check(changed, "Pose membeku pada " + clip)
		_check(animation.get_animation(clip).loop_mode == Animation.LOOP_LINEAR,
			"Animasi tidak loop: " + clip)
	character.update_motion(1.8)
	_check(character.state == Character.WALK, "Kecepatan jalan tidak memilih Walk")
	character.update_motion(5.0)
	_check(character.state == Character.RUN, "Kecepatan lari tidak memilih Jog_Fwd")
	character.update_motion(2.6)
	_check(character.state == Character.RUN, "Histeresis lari gagal")
	character.update_motion(2.0)
	_check(character.state == Character.WALK, "Transisi lari ke jalan gagal")
	character.update_motion(0.0)
	_check(character.state == Character.IDLE, "Berhenti tidak memilih Idle")
	_check(not character.find_children("*", "MeshInstance3D", true, false).is_empty(),
		"Mesh mannequin hilang")
	_test_cast(character, skeleton)
	print("[mannequin-test] gagal: ", _failures)
	quit(0 if _failures == 0 else 1)


func _test_cast(character: Character, skeleton: Skeleton3D) -> void:
	var layer := character.cast_layer
	_check(layer != null and layer.tracks.size() > 20, "Layer casting/filter hilang")
	if layer == null:
		return
	_check(layer.clip.loop_mode == Animation.LOOP_NONE, "Casting tidak boleh loop")
	for bone: int in layer.tracks.values():
		var name := skeleton.get_bone_name(bone)
		_check(not name.contains("thigh") and not name.contains("calf")
			and not name.contains("foot") and name != "root" and name != "pelvis",
			"Casting mengambil alih kaki/root: " + name)
	for motion in [Character.IDLE, Character.WALK, Character.RUN]:
		character.animation.play(motion, 0)
		character.animation.advance(0.2)
		var original: Array[Quaternion] = []
		for bone in range(skeleton.get_bone_count()):
			original.append(skeleton.get_bone_pose_rotation(bone))
		character.start_cast()
		layer._physics_process(0.2)
		layer._process_modification_with_delta(0)
		var changed := 0
		for bone in range(skeleton.get_bone_count()):
			var differs := not original[bone].is_equal_approx(skeleton.get_bone_pose_rotation(bone))
			if layer.tracks.values().has(bone):
				changed += int(differs)
			else:
				_check(not differs, "Casting mengubah tulang locomotion: "
					+ skeleton.get_bone_name(bone))
		_check(changed > 10, "Pose upper-body tidak berubah pada " + motion)
		_check(character.animation.current_animation == motion, "Casting mengganti clock langkah")
		layer._physics_process(0.4)
		_check(not layer.playing and not layer.active and layer.influence == 0,
			"Casting tidak kembali ke locomotion")
		character.animation.advance(0)
