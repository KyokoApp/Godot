extends SceneTree
## Gerbang untuk avatar Aurelia: peta tulang, retarget, material, dan goyangan
## kain/rambut. Semua tanpa gambar (headless) supaya bisa jalan di CI.
##
## Yang diuji BUKAN "tidak ada error", tapi hasilnya:
##   - avatar benar-benar mengikuti arah tulang animasi (bukan patung, bukan pula
##     T-pose kaku seperti retarget selisih-rest),
##   - kain/rambut menggantung, tertinggal saat badan bergerak (punya kelembaman),
##     lalu menyusul kembali,
##   - tidak ada partikel kain yang menembus kepala/badan.

const Character = preload("res://src/game/character/aurelia_visual.gd")
const Humanoid = preload("res://src/game/animation/humanoid_map.gd")
const Springs = preload("res://src/game/animation/cloth_springs.gd")
const STEP := 1.0 / 60.0
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
	await process_frame
	if character.avatar == null or character.retarget == null or character.cloth == null:
		print("::error::karakter Aurelia tidak lengkap")
		quit(1)
		return
	print(character.status)
	_test_rig(character)
	_test_materials(character)
	_test_retarget_shape(character)
	_test_feet_above_ground(character)
	_test_cloth_inertia(character)
	_test_cloth_no_penetration(character)
	print("[aurelia-test] tulang=%d dipetakan=%d rantai=%d gagal=%d" % [
		character.avatar.get_bone_count(), character.retarget.mapped_count(),
		character.cloth.springs.chain_count(), _failures])
	quit(0 if _failures == 0 else 1)


func _test_rig(character: Character) -> void:
	_check(character.rig_model != null and not character.rig_model.visible,
		"Rig animasi UAL seharusnya disembunyikan")
	_check(character.avatar.get_bone_count() > 150,
		"Tulang avatar kurang: %d" % character.avatar.get_bone_count())
	var missing := Humanoid.missing_pairs(character.skeleton, character.avatar)
	_check(missing.is_empty(), "Pasangan tulang tidak ditemukan: " + ", ".join(missing))
	_check(character.retarget.mapped_count() == Humanoid.PAIRS.size(),
		"Peta tulang tidak lengkap: %d dari %d" % [character.retarget.mapped_count(),
		Humanoid.PAIRS.size()])
	_check(character.retarget.motion_scale() > 0.7 and character.retarget.motion_scale() < 1.05,
		"Skala gerak tidak wajar: %.3f" % character.retarget.motion_scale())
	var springs: Springs = character.cloth.springs
	_check(springs.chain_count() >= 40, "Rantai kain terlalu sedikit: %d"
		% springs.chain_count())
	_check(springs.bone_count() >= 60, "Tulang kain terlalu sedikit: %d"
		% springs.bone_count())
	_check(springs.collider_count() >= 12, "Kapsul badan terlalu sedikit: %d"
		% springs.collider_count())


func _test_materials(character: Character) -> void:
	var visible := 0
	for node in character.avatar.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.visible:
			continue
		visible += 1
		var material := mesh.material_override as StandardMaterial3D
		_check(material != null, "Material avatar hilang di " + mesh.name)
		if material == null:
			continue
		_check(material.albedo_texture != null,
			"Tekstur avatar hilang di " + mesh.name)
		_check(material.next_pass is ShaderMaterial, "Outline avatar hilang di "
			+ mesh.name)
	# 8 mesh asli; satu (EffectMesh) sengaja disembunyikan.
	_check(visible == 7, "Jumlah mesh avatar yang tampil bukan 7: %d" % visible)


## Arah tulang avatar harus sama dengan arah tulang animasi — inilah bukti
## retarget benar. Kalau rumusnya memakai selisih rest (T-pose vs A-pose),
## lengannya berbeda ±50 derajat dan uji ini gagal.
func _test_retarget_shape(character: Character) -> void:
	for motion in ["Idle_Loop", "Jog_Fwd_Loop", "Sprint_Loop", "Crouch_Fwd_Loop"]:
		character.set_locomotion(motion, 1.0)
		character.animation.advance(0.0)
		for step in range(20):
			character.animation.advance(STEP)
			character.retarget.apply()
			if step % 4 != 0:
				continue
			_check(_directions_match(character, "lowerarm_l", "Bip001 L Forearm"),
				"Lengan bawah avatar menyimpang dari animasi: " + motion)
			_check(_directions_match(character, "calf_l", "Bip001 L Calf"),
				"Betis avatar menyimpang dari animasi: " + motion)
			_check(_directions_match(character, "hand_r", "Bip001 R Hand"),
				"Tangan avatar menyimpang dari animasi: " + motion)
		# Bukti tambahan: pose avatar BUKAN T-pose.
		var upper := character.avatar.find_bone("Bip001 L UpperArm")
		var rest := character.avatar.get_bone_global_rest(upper)
		var now := character.avatar.get_bone_global_pose(upper)
		var angle := rest.basis.get_rotation_quaternion().angle_to(
			now.basis.get_rotation_quaternion())
		if motion == "Idle_Loop":
			_check(angle > 0.25, "Lengan avatar masih T-pose saat idle: %.1f derajat"
				% rad_to_deg(angle))


func _directions_match(character: Character, source_name: String, target_name: String) -> bool:
	var source_bone := character.skeleton.find_bone(source_name)
	var target_bone := character.avatar.find_bone(target_name)
	if source_bone < 0 or target_bone < 0:
		return false
	var source_child := _mapped_child(character.skeleton, source_bone)
	var target_child := _mapped_child(character.avatar, target_bone)
	if source_child < 0 or target_child < 0:
		return false
	var source_direction := (character.skeleton.get_bone_global_pose(source_child).origin
		- character.skeleton.get_bone_global_pose(source_bone).origin).normalized()
	var target_direction := (character.avatar.get_bone_global_pose(target_child).origin
		- character.avatar.get_bone_global_pose(target_bone).origin).normalized()
	return source_direction.dot(target_direction) > 0.97


func _longest_hair_chain(springs: Springs) -> int:
	var best := -1
	var best_length := 0.0
	for index in range(springs.chain_count()):
		var names := springs.chain_bone_names(index)
		if names.is_empty() or not names[0].begins_with("Bone_Hair"):
			continue
		var length := springs.chain_length(index)
		if length > best_length:
			best_length = length
			best = index
	return best


func _mapped_child(skeleton: Skeleton3D, bone: int) -> int:
	for child in range(skeleton.get_bone_count()):
		if skeleton.get_bone_parent(child) == bone:
			return child
	return -1


## Kaki tidak boleh menembus tanah di klip berdiri/jalan (skala gerak retarget).
func _test_feet_above_ground(character: Character) -> void:
	for motion in ["Idle_Loop", "Walk_Loop", "Crouch_Fwd_Loop"]:
		character.set_locomotion(motion, 1.0)
		character.animation.advance(0.0)
		var lowest := INF
		for step in range(40):
			character.animation.advance(STEP)
			character.retarget.apply()
			for side in ["Bip001 L Foot", "Bip001 R Foot"]:
				var bone := character.avatar.find_bone(side)
				lowest = minf(lowest,
					character.avatar.get_bone_global_pose(bone).origin.y)
		_check(lowest > -0.03, "Telapak menembus tanah di %s: %.3f m" % [motion, lowest])


## Goyangan kain: saat badan dipindah mendadak, ujung kain harus TERTINGGAL dulu
## (bukti simulasi punya kelembaman), lalu menyusul, dan akhirnya berhenti
## berayun. Kain yang menempel kaku akan langsung ikut tanpa selisih.
func _test_cloth_inertia(character: Character) -> void:
	var springs: Springs = character.cloth.springs
	var chain := _longest_hair_chain(springs)
	_check(chain >= 0, "Tidak ada rantai rambut panjang untuk diuji")
	if chain < 0:
		return
	var tip := springs.particle(chain, springs.chain_bones(chain).size())
	# Dudukkan dulu supaya simulasi tenang.
	for step in range(90):
		character.cloth.simulate(STEP)
	var settled := springs.particle(chain, springs.chain_bones(chain).size())
	_check(settled.y < tip.y + 0.001, "Rambut tidak menggantung ke bawah")
	character.global_position += Vector3(1.0, 0.0, 0.0)
	character.cloth.simulate(STEP)
	character.cloth.simulate(STEP)
	var lagging := springs.particle(chain, springs.chain_bones(chain).size())
	var body_move := 1.0
	var cloth_move := lagging.distance_to(settled)
	_check(cloth_move < body_move * 0.6, "Kain menempel kaku, tidak tertinggal: %.3f m"
		% cloth_move)
	_check(cloth_move > body_move * 0.05, "Kain tidak bergerak sama sekali: %.3f m"
		% cloth_move)
	for step in range(120):
		character.cloth.simulate(STEP)
	var caught_up := springs.particle(chain, springs.chain_bones(chain).size())
	var rest_point := character.avatar.global_transform * Vector3.ZERO
	_check(caught_up.distance_to(lagging) > 0.2 * body_move,
		"Kain tidak menyusul badan setelah badan diam")
	_check(not is_equal_approx(caught_up.x, rest_point.x),
		"Kain ikut menempel ke titik asal badan")


## Rambut panjang tidak boleh menembus kepala/badan saat diam.
func _test_cloth_no_penetration(character: Character) -> void:
	var springs: Springs = character.cloth.springs
	var head := character.avatar.find_bone("Bip001 Head")
	var neck := character.avatar.find_bone("Bip001 Neck")
	if head < 0 or neck < 0:
		return
	character.global_position = Vector3.ZERO
	character.rotation = Vector3.ZERO
	for step in range(120):
		character.cloth.simulate(STEP)
	var head_center := character.avatar.get_bone_global_pose(head).origin
	var neck_axis := character.avatar.get_bone_global_pose(neck).origin
	var worst := INF
	for index in range(springs.chain_count()):
		var names := springs.chain_bone_names(index)
		if names.is_empty() or not names[0].begins_with("Bone_Hair"):
			continue
		var tip := springs.particle(index, names.size())
		worst = minf(worst, tip.distance_to(head_center) - 0.10)
		worst = minf(worst, tip.distance_to(neck_axis) - 0.10)
	_check(worst > -0.02, "Rambut menembus kepala/badan: %.3f m" % worst)
