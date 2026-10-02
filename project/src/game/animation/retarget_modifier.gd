extends SkeletonModifier3D
## Retarget pose: rig animasi UAL (sumber) -> kerangka avatar Aurelia (target).
##
## Klip UAL dimainkan di rig mannequin yang TIDAK digambar; modul ini menyalin
## pose hasilnya ke tulang avatar. Modul ini anak rig sumber dan berada SESUDAH
## lapisan cast, supaya gerakan casting ikut tersalin.
##
## Kenapa tidak memakai rumus "selisih dari rest pose" (seperti
## RetargetModifier3D bawaan Godot):
##   Mannequin UAL berdiri T-pose (lengan mendatar), avatar Aurelia berdiri
##   A-pose (lengan 50 derajat ke bawah). Kalau yang dipindah hanya SELISIH dari
##   rest masing-masing, avatar akan selalu 50 derajat lebih rendah daripada
##   animasinya — tangan masuk ke dalam badan. Yang benar adalah memindahkan
##   BENTUK: arah tulang avatar harus sama persis dengan arah tulang sumber.
##
## Rumus yang dipakai per tulang:
##   1. arah   : sumbu tulang sumber saat ini (di ruang model) dipakai apa adanya,
##               lalu diputar dari sumbu rest avatar (swing paling pendek).
##   2. puntiran: selisih rotasi global sumber dari rest-nya diurai jadi
##               swing + twist terhadap sumbu rest sumber; sudutnya dipakai
##               sebagai puntiran avatar terhadap sumbu rest avatar.
##   3. letak  : sama seperti rumus bawaan Godot (selisih dari rest, dikali
##               skala gerak) supaya naik-turun pinggul tetap sepadan ukuran.
##
## (2) penting: tanpa puntiran, putaran pinggul saat berjalan dan telapak kaki
## yang menekuk hilang karena sumbu tulang-tulang itu hampir vertikal.

const Humanoid = preload("res://src/game/animation/humanoid_map.gd")

var _source: Skeleton3D
var _target: Skeleton3D
var _count := 0
var _source_bones := PackedInt32Array()
var _target_bones := PackedInt32Array()
## Sumbu tulang sumber di ruang lokalnya (tetap), sumbu rest avatar di ruang
## model, dan bidang rest kedua sisi (untuk selisih global).
var _source_axis_local := PackedVector3Array()
var _target_axis := PackedVector3Array()
var _source_axis := PackedVector3Array()
var _source_rest_basis: Array[Basis] = []
var _target_rest_basis: Array[Basis] = []
var _source_rest_origin := PackedVector3Array()
var _target_rest_origin := PackedVector3Array()
## Perpindahan posisi: ruang induk rest avatar <- ruang induk rest sumber.
var _pre: Array[Basis] = []
## Tulang daun (Nub) tidak menggerakkan geometri: cukup diletakkan, tidak diputar.
var _leaf := PackedByteArray()
## Indeks pasangan induk (yang dipetakan) atau -1.
var _parent_pair := PackedInt32Array()
var _pair_of_source: Dictionary = {}
var _pair_of_target: Dictionary = {}
## Hasil per hitungan, dipakai anak-anaknya di baris berikutnya.
var _wanted: Dictionary = {}
var _motion_scale := 1.0
var _skipped := 0


func configure(source: Skeleton3D, target: Skeleton3D) -> void:
	_source = source
	_target = target
	_reset()
	if source == null or target == null:
		push_error("Retarget: rig sumber/target kosong")
		return
	for pair: Vector2i in Humanoid.resolve(source, target):
		_pair_of_source[pair.x] = _count
		_pair_of_target[pair.y] = _count
		_source_bones.append(pair.x)
		_target_bones.append(pair.y)
		_count += 1
	if _count == 0:
		push_error("Retarget: tidak ada tulang yang cocok antara UAL dan avatar")
		return
	# Urutkan supaya induk selalu dihitung sebelum anak (dipakai untuk menyusun
	# rotasi lokal dari rotasi global yang diinginkan).
	var order: Array[int] = []
	for index in range(_count):
		order.append(index)
	var depth := PackedInt32Array()
	depth.resize(_count)
	for index in range(_count):
		depth[index] = _depth_of(source, _source_bones[index])
	order.sort_custom(func(a: int, b: int) -> bool: return depth[a] < depth[b])
	_reorder(order)
	_measure()
	_motion_scale = _compute_motion_scale(source, target)
	_skipped = Humanoid.PAIRS.size() - _count
	if _axis_missing() > 0:
		push_warning("Retarget: %d tulang tanpa arah (tulang daun)" % _axis_missing())


func _reset() -> void:
	_count = 0
	_source_bones = PackedInt32Array()
	_target_bones = PackedInt32Array()
	_source_axis_local = PackedVector3Array()
	_target_axis = PackedVector3Array()
	_source_axis = PackedVector3Array()
	_source_rest_basis = []
	_target_rest_basis = []
	_source_rest_origin = PackedVector3Array()
	_target_rest_origin = PackedVector3Array()
	_pre = []
	_leaf = PackedByteArray()
	_parent_pair = PackedInt32Array()
	_pair_of_source = {}
	_pair_of_target = {}
	_wanted = {}
	_skipped = 0


func _depth_of(skeleton: Skeleton3D, bone: int) -> int:
	var depth := 0
	var parent := skeleton.get_bone_parent(bone)
	while parent >= 0 and depth < 64:
		depth += 1
		parent = skeleton.get_bone_parent(parent)
	return depth


func _reorder(order: Array[int]) -> void:
	var source_bones := _source_bones
	var target_bones := _target_bones
	_source_bones = PackedInt32Array()
	_target_bones = PackedInt32Array()
	var pair_of_source: Dictionary = {}
	var pair_of_target: Dictionary = {}
	for index in order:
		pair_of_source[source_bones[index]] = _source_bones.size()
		pair_of_target[target_bones[index]] = _source_bones.size()
		_source_bones.append(source_bones[index])
		_target_bones.append(target_bones[index])
	_pair_of_source = pair_of_source
	_pair_of_target = pair_of_target


## Hitung sumbu, bidang rest, dan aturan perpindahan posisi untuk tiap pasangan.
func _measure() -> void:
	_leaf.resize(_count)
	_parent_pair.resize(_count)
	for index in range(_count):
		var source_bone := _source_bones[index]
		var target_bone := _target_bones[index]
		var source_rest := _source.get_bone_global_rest(source_bone)
		var target_rest := _target.get_bone_global_rest(target_bone)
		var parent_pair := _parent_pair_of(target_bone)
		_parent_pair[index] = parent_pair
		# Sumbu tulang = arah ke anak yang juga dipetakan (anak langsung di kedua
		# sisi). Tulang tanpa anak seperti itu (Nub) dianggap daun.
		var axis_source := Vector3.ZERO
		var axis_target := Vector3.ZERO
		for child in range(_source.get_bone_count()):
			if _source.get_bone_parent(child) != source_bone:
				continue
			if not _pair_of_source.has(child):
				continue
			var child_target: int = _target_bones[_pair_of_source[child]]
			if _target.get_bone_parent(child_target) != target_bone:
				continue
			axis_source = _source.get_bone_global_rest(child).origin - source_rest.origin
			axis_target = _target.get_bone_global_rest(child_target).origin - target_rest.origin
			break
		var has_axis := axis_source.length() > 0.0005 and axis_target.length() > 0.0005
		_leaf.append(0 if has_axis else 1)
		var source_axis := axis_source.normalized()
		_source_axis.append(source_axis)
		_source_axis_local.append((source_rest.basis.inverse() * source_axis).normalized())
		_target_axis.append(axis_target.normalized())
		_source_rest_basis.append(source_rest.basis)
		_target_rest_basis.append(target_rest.basis)
		_source_rest_origin.append(source_rest.origin)
		_target_rest_origin.append(target_rest.origin)
		_pre.append(_parent_global_rest(_target, target_bone).basis.inverse()
			* _parent_global_rest(_source, source_bone).basis)


func _axis_missing() -> int:
	var missing := 0
	for value in _leaf:
		missing += value
	return missing


func _parent_pair_of(target_bone: int) -> int:
	var parent := _target.get_bone_parent(target_bone)
	if parent < 0 or not _pair_of_target.has(parent):
		return -1
	return _pair_of_target[parent]


func _parent_global_rest(skeleton: Skeleton3D, bone: int) -> Transform3D:
	var parent := skeleton.get_bone_parent(bone)
	if parent < 0:
		return Transform3D()
	return skeleton.get_bone_global_rest(parent)


## Selisih tinggi kaki (pinggul->telapak) dipakai untuk menskalakan perpindahan
## pinggul: avatar 1,64 m, mannequin UAL ±1,8 m, jadi tanpa skala ini pinggul
## turun terlalu dalam dan telapak menembus tanah setiap klip jongkok.
func _compute_motion_scale(source: Skeleton3D, target: Skeleton3D) -> float:
	var source_leg := _leg_length(source, "thigh_l", "foot_l")
	var target_leg := _leg_length(target, "Bip001 L Thigh", "Bip001 L Foot")
	if source_leg <= 0.05 or target_leg <= 0.05:
		return 1.0
	return clampf(target_leg / source_leg, 0.5, 2.0)


func _leg_length(skeleton: Skeleton3D, upper: String, lower: String) -> float:
	var upper_bone := Humanoid.find_bone(skeleton, upper)
	var lower_bone := Humanoid.find_bone(skeleton, lower)
	if upper_bone < 0 or lower_bone < 0:
		return 0.0
	return absf(skeleton.get_bone_global_rest(upper_bone).origin.y
		- skeleton.get_bone_global_rest(lower_bone).origin.y)


# --------------------------------------------------------------- per frame ----

## Dipanggil Skeleton3D sesudah semua AnimationMixer selesai.
func _process_modification_with_delta(_delta: float) -> void:
	apply()


func apply() -> void:
	if _source == null or _target == null or _count == 0:
		return
	for index in range(_count):
		var source_bone := _source_bones[index]
		var target_bone := _target_bones[index]
		var source_pose := _source.get_bone_global_pose(source_bone)
		# --- letak: selisih dari rest, dikali skala gerak.
		var position := _pre[index] * ((source_pose.origin - _source_rest_origin[index])
			* _motion_scale) + _target_rest_origin[index]
		_target.set_bone_pose_position(target_bone, position)
		if _leaf[index] == 1:
			continue
		# --- arah: persis arah tulang sumber, diambil dari sumbu rest avatar.
		var direction := (source_pose.basis * _source_axis_local[index]).normalized()
		var swing := _rotation_between(_target_axis[index], direction)
		# --- puntiran: selisih global sumber dari rest, diurai swing + twist.
		var delta := source_pose.basis * _source_rest_basis[index].inverse()
		var twist := _twist_angle(delta, _source_axis[index])
		var wanted := swing * Basis(_target_axis[index], twist) * _target_rest_basis[index]
		var parent_basis := _parent_basis(index, target_bone)
		var local := parent_basis.inverse() * wanted
		_target.set_bone_pose_rotation(target_bone,
			local.orthonormalized().get_rotation_quaternion())
		_wanted[target_bone] = wanted


## Rotasi global yang dipakai: hasil hitung sendiri kalau induknya dipetakan,
## kalau tidak pakai pose avatar apa adanya (tulang itu tidak pernah diubah).
func _parent_basis(index: int, target_bone: int) -> Basis:
	var parent_pair := _parent_pair[index]
	if parent_pair >= 0:
		var wanted: Basis = _wanted[_target_bones[parent_pair]]
		return wanted
	var parent := _target.get_bone_parent(target_bone)
	if parent < 0:
		return Basis()
	return _target.get_bone_global_pose(parent).basis


## Sudut puntiran (bertanda) dari `delta` terhadap sumbu `axis`.
static func _twist_angle(delta: Basis, axis: Vector3) -> float:
	var rotation := delta.get_rotation_quaternion()
	if rotation.w < 0.0:
		rotation = Quaternion(-rotation.x, -rotation.y, -rotation.z, -rotation.w)
	var projected := Vector3(rotation.x, rotation.y, rotation.z).dot(axis)
	var twist := Quaternion(axis.x * projected, axis.y * projected,
		axis.z * projected, rotation.w)
	if twist.length_squared() < 0.0000000001:
		return 0.0
	twist = twist.normalized()
	var angle := twist.get_angle()
	if angle < 0.0001:
		return 0.0
	return angle * signf(twist.get_axis().dot(axis))


static func _rotation_between(from: Vector3, to: Vector3) -> Basis:
	var dot := clampf(from.dot(to), -1.0, 1.0)
	if dot > 0.999999:
		return Basis()
	if dot < -0.999999:
		var axis := from.cross(Vector3.RIGHT)
		if axis.length_squared() < 0.000001:
			axis = from.cross(Vector3.UP)
		return Basis(axis.normalized(), PI)
	var cross := from.cross(to)
	return Basis(Quaternion(cross.x, cross.y, cross.z, 1.0 + dot).normalized())


# ------------------------------------------------------------------ laporan ----

func mapped_count() -> int:
	return _count


func motion_scale() -> float:
	return _motion_scale


func skipped_count() -> int:
	return _skipped


func report() -> String:
	return "[retarget] %d tulang dipetakan (%d daun), %d dilewati, skala gerak %.3f" % [
		mapped_count(), _axis_missing(), _skipped, _motion_scale]
