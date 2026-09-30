extends SceneTree
## Required engine gate: importing a valid GLB alone does not prove animation retarget.

const Character = preload("res://src/game/mannequin.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _run() -> void:
	var character := Character.new()
	root.add_child(character)
	for selected in [Character.MIKU, Character.KANNA]:
		await _test_skin(character, selected)
	character.queue_free()
	await process_frame
	print("[skin-switch-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)


func _test_skin(character: Character, selected: String) -> void:
	var kanna := selected == Character.KANNA
	var hips_name := "root" if kanna else "J_Bip_C_Hips"
	var head_name := "DEF-Head" if kanna else "J_Bip_C_Head"
	var legs := ["DEF-Left leg", "DEF-Right leg", "root"] if kanna else [
		"J_Bip_L_UpperLeg", "J_Bip_R_UpperLeg", "J_Bip_C_Hips"]
	character.animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	character.cast_layer.set_physics_process(true)
	_check(character.set_skin(selected), "Miku gagal dibuat")
	if character.skin == null:
		return
	_check(character.retarget.pairs.size() == (50 if kanna else 52), "Pemetaan rig tidak lengkap")
	var destination := character.retarget.target
	var hips := destination.find_bone(hips_name)
	var head := destination.find_bone(head_name)
	_check(destination.get_bone_global_pose(head).origin.y > 1.0, "Miku rebah/tenggelam")
	_check(destination.get_bone_global_pose(hips).origin.y > 0.5, "Posisi pelvis salah")
	var count := character.retarget.transfers
	for frame in range(5):
		await process_frame
	_check(character.retarget.transfers > count, "Rig tersembunyi berhenti mentransfer")
	for motion in [Character.IDLE, Character.WALK, Character.RUN]:
		character.animation.play(motion, 0)
		character.animation.advance(0.1)
		character.retarget.transfer()
		var before := _rotations(destination)
		character.animation.advance(0.3)
		character.retarget.transfer()
		_check(_changed(before, _rotations(destination)) > 8, "Pose Miku beku: " + motion)
		_check(destination.get_bone_global_pose(head).origin.y > 1.0, "Miku tidak tegak")
	# Source's final modifier must see the weighted casting layer.
	character.animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	character.cast_layer.set_physics_process(false)
	character.animation.play(Character.RUN, 0)
	character.animation.advance(0.2)
	character.retarget.transfer()
	var before_cast := _rotations(destination)
	character.start_cast()
	character.cast_layer._physics_process(0.2)
	for frame in range(5):
		character.animation.advance(0)
		await process_frame
	var after_cast := _rotations(destination)
	_check(_changed(before_cast, after_cast) > 10, "Casting tidak sampai ke Miku")
	for name in legs:
		var bone := destination.find_bone(name)
		_check(before_cast[bone].is_equal_approx(after_cast[bone]), "Casting mengubah kaki Miku")
	var cached := character.skin.get_instance_id()
	for index in range(20):
		_check(character.set_skin(Character.MANNEQUIN), "Gagal kembali ke mannequin")
		_check(not character.skin.visible and not character.retarget.active, "Miku tetap aktif")
		_check(character.set_skin(selected), "Gagal kembali ke Miku")
		_check(character.skin.get_instance_id() == cached, "Switch membuat model duplikat")
	_check(character.cast_layer.playing, "Switch mereset casting")
	character.cast_layer._physics_process(1.0)


func _rotations(skeleton: Skeleton3D) -> Array[Quaternion]:
	var result: Array[Quaternion] = []
	for bone in range(skeleton.get_bone_count()):
		result.append(skeleton.get_bone_pose_rotation(bone))
	return result


func _changed(before: Array[Quaternion], after: Array[Quaternion]) -> int:
	var count := 0
	for bone in range(before.size()):
		count += int(not before[bone].is_equal_approx(after[bone]))
	return count
