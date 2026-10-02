extends RefCounted
## Inti simulasi goyangan kain & rambut (tanpa node, bisa diuji headless).
##
## Cara kerjanya: setiap rantai tulang kain (rok "Shawl", "Hair", "Collar", "Hip",
## "Pendant", "Earrings", "+Flycloak") diperlakukan sebagai rantai partikel yang
## disimulasikan dengan verlet di RUANG DUNIA:
##
##   1. partikel pertama selalu menempel di tulang badannya (dari animasi),
##   2. sisanya jatuh karena gravitasi + angin, dan menyimpan kecepatan sendiri,
##   3. tiap iterasi: panjang segmen dijaga, arah segmen ditarik balik ke bentuk
##      rest-nya (kekakuan kain), lalu didorong keluar dari kapsul badan DAN dari
##      kapsul kain lain yang lebih dalam (aturan lapisan, lihat WEAVE_RADIUS),
##   4. arah partikel diterjemahkan kembali menjadi rotasi tulang.
##
## Kenapa di ruang dunia dan bukan ruang model: supaya kain punya KELEMBAMAN.
## Saat pemain berbelok atau berlari, partikel tertinggal di belakang karena
## posisinya di dunia, bukan menempel kaku di badan. Inilah bedanya "kain kaku
## seperti karton" dengan "kain yang benar-benar mengikuti badan".

const Humanoid = preload("res://src/game/animation/humanoid_map.gd")

## Ambang minimum gerak supaya simulasi tidak "meletus" saat frame drop.
const MIN_DELTA := 1.0 / 240.0
const MAX_DELTA := 1.0 / 30.0
## Kain yang lebih panjang dari ini tetap dihitung, tapi rantai yang bercabang
## tidak digabung (rok punya banyak panel; tiap panel = satu rantai).
## Seberapa jauh (dari rest pose) sebuah kapsul badan masih diikutkan ke rantai.
## Nilai kecil (0,22) membuat rok/rambut tidak pernah bertabrakan dengan kaki:
## saat kaki mengayun ke depan, kain yang menggantung di dekat pinggul sudah
## menembus paha sebelum kapsulnya dihitung. 0,55 cukup untuk semua panel rok
## pada avatar ini tanpa perlu menguji 16 kapsul untuk tiap partikel.
const MAX_COLLIDER_MARGIN := 0.55
const GROUND_FRICTION := 0.55
## Iterasi penjaga bentuk untuk mode normal (mode ringan memakai 1).
const DEFAULT_ITERATIONS := 2
## Kecepatan basis acuan mengejar arah badan (1/detik).
const BASIS_FOLLOW := 6.0


## Setelan per grup tulang. "prefix" dicocokkan setelah nama tulang
## dinormalisasi, jadi tanda "+" atau spasi di nama tidak masalah.
##   stiffness : seberapa cepat kain kembali ke bentuk rest (1/detik)
##   drag      : redaman kecepatan (1/detik)
##   gravity   : pengali gravitasi (rambut sedikit lebih ringan dari rok)
##   wind      : pengali angin
##   weave     : ikut aturan lapisan kain-vs-kain (lihat WEAVE_RADIUS)
##   hang      : seberapa kuat ujung rantai jatuh ke arah bawah (0..1). Pose
##               rest model ini adalah pose patung: cape-nya terbentang ke
##               belakang. Tanpa `hang`, penjaga bentuk menarik kain KEMBALI ke
##               sudut itu terus-menerus dan hasilnya kaku seperti papan.
##               `hang` memutar arah acuan tiap segmen ke arah gravitasi, makin
##               besar di ujung rantai; jadi lekukan/krinyit kain tetap ada tapi
##               panel benar-benar menggantung.
##
## Kekakuan kain dipilih rendah (9,5/detik) karena inilah yang membedakan
## "kain" dari "karton": dengan rest-shape yang ditarik perlahan, panel baru
## kembali ke bentuk aslinya setelah beberapa saat, jadi terlihat mengalir.
##
## Leher TIDAK ada di daftar ini. Geometri leher digerakkan `Bone_NeckA01_M`
## (476 titik, anak `Bip001 Neck`); saat ikut disimulasikan, kulit leher
## tertarik ke arah gravitasi sehingga leher terlihat kurus dan memanjang.
## Leher cukup mengikuti animasi badan seperti tulang tubuh lainnya.
const GROUPS := [
	{"prefix": "Bone_Hair", "stiffness": 30.0, "drag": 2.6, "gravity": 1.0,
		"wind": 0.55, "weave": false, "hang": 0.30},
	{"prefix": "Bone_Shawl", "stiffness": 9.5, "drag": 1.45, "gravity": 1.0,
		"wind": 0.85, "weave": true, "hang": 0.90},
	{"prefix": "Bone_Collar", "stiffness": 28.0, "drag": 2.4, "gravity": 1.0,
		"wind": 0.7, "weave": true, "hang": 0.40},
	{"prefix": "Bone_Hip", "stiffness": 34.0, "drag": 3.0, "gravity": 1.0,
		"wind": 0.5, "weave": true, "hang": 0.75},
	{"prefix": "Bone_Pendant", "stiffness": 42.0, "drag": 3.2, "gravity": 1.0,
		"wind": 0.4, "weave": false, "hang": 1.0},
	{"prefix": "Bone_Earrings", "stiffness": 48.0, "drag": 3.4, "gravity": 1.0,
		"wind": 0.3, "weave": false, "hang": 1.0},
	{"prefix": "Flycloak", "stiffness": 12.0, "drag": 1.6, "gravity": 1.0,
		"wind": 0.9, "weave": true, "hang": 0.90},
]

## Bagian rantai teratas masih memakai sudut rest (supaya sambungan ke badan
## tidak patah); mulai dari pecahan ini ke ujung, jatuh ke arah bawah.
const HANG_RAMP_FROM := 0.20

## Tulang kain yang TIDAK boleh disimulasikan. `Bone_ShawlJ01_L` dan
## `Bone_ShawlK01_L` menggantung di `Bone_ShawlArmTwistA01_L` (anak
## `Bip001 L UpperArm`), jadi mereka berputar bersama lengan. Kalau digoyangkan
## gravitasi, panel lengan itu menyayat jubah badan setiap lengan diangkat;
## lebih baik kaku mengikuti lengan seperti aslinya.
const SKIP_BONES := ["Bone_ShawlArmTwist", "Bone_ShawlJ", "Bone_ShawlK"]

## Kain vs kain: tiap rantai dihitung "lapisan"-nya (rata-rata jarak titik rest
## ke kapsul badan). Rantai yang lebih LUAR tidak boleh masuk ke kapsul rantai
## yang lebih dalam — inilah yang menghentikan kain menembus kain lain, bukan
## cuma menembus badan. Radiusnya kecil (2 cm) supaya kain tetap terlihat
## menempel; yang dijaga hanya URUTAN lapisannya.
const WEAVE_RADIUS := 0.02
## Selisih jarak minimum supaya dua rantai dianggap beda lapisan.
const WEAVE_LAYER_EPS := 0.005
## Hanya segmen kain lain yang sedekat ini (di rest pose) yang diikutkan.
const WEAVE_REACH := 0.10
## Batas kapsul kain per rantai supaya biaya per frame tetap kecil.
const MAX_WEAVE_CAPSULES := 6

## Kapsul tabrakan badan: [tulang A, tulang B, ekor, radius].
## Segmen = A.origin -> B.origin (kalau B kosong: A.origin lanjut ke arah
## tulang induk A). "ekor" memanjangkan segmen melewati B sebagai kelipatan
## panjang segmen. Semua dihitung dari REST pose, jadi tetap benar walau
## importer mengubah skala model.
const COLLIDERS := [
	["Bip001 Neck", "Bip001 Head", 2.6, 0.115],
	["Bip001 Spine1", "Bip001 Spine2", 0.30, 0.115],
	["Bip001 Spine", "Bip001 Spine1", 0.0, 0.105],
	["Bip001 Pelvis", "Bip001 Spine", 0.0, 0.115],
	["Bip001 L Clavicle", "Bip001 L UpperArm", 0.0, 0.060],
	["Bip001 L UpperArm", "Bip001 L Forearm", 0.0, 0.052],
	["Bip001 L Forearm", "Bip001 L Hand", 0.0, 0.046],
	["Bip001 R Clavicle", "Bip001 R UpperArm", 0.0, 0.060],
	["Bip001 R UpperArm", "Bip001 R Forearm", 0.0, 0.052],
	["Bip001 R Forearm", "Bip001 R Hand", 0.0, 0.046],
	["Bip001 L Thigh", "Bip001 L Calf", 0.0, 0.078],
	["Bip001 L Calf", "Bip001 L Foot", 0.0, 0.058],
	["Bip001 L Foot", "Bip001 L Toe0", 0.0, 0.060],
	["Bip001 R Thigh", "Bip001 R Calf", 0.0, 0.078],
	["Bip001 R Calf", "Bip001 R Foot", 0.0, 0.058],
	["Bip001 R Foot", "Bip001 R Toe0", 0.0, 0.060],
]


class Capsule:
	var bone := -1
	## Indeks rantai kain pemilik kapsul ini; -1 berarti kapsul badan.
	var chain := -1
	var from_local := Vector3.ZERO
	var to_local := Vector3.ZERO
	var radius := 0.1
	var from_world := Vector3.ZERO
	var to_world := Vector3.ZERO


class Strand:
	var bones := PackedInt32Array()
	var parent_bone := -1
	## Partikel 0..n: 0 = pangkal tulang pertama, n = ujung tulang terakhir.
	var points := PackedVector3Array()
	var prev := PackedVector3Array()
	## Offset tiap partikel di ruang REST tulang penggantung.
	var rest_local := PackedVector3Array()
	## Panjang tiap segmen (indeks 1..n dipakai).
	var lengths := PackedFloat32Array()
	## Arah segmen i di ruang tulang i (dipakai untuk kekakuan).
	var dir_local := PackedVector3Array()
	## Basis rest tulang i relatif tulang sebelumnya (atau penggantungnya).
	var rel_basis: Array[Basis] = []
	## Basis dunia untuk membentuk ulang rantai: campuran basis TETAP modul ini
	## (supaya rantai benar-benar menggantung ke bawah walau badan miring) dan
	## basis tulang penggantung yang beranimasi (supaya rambut ikut menoleh).
	var gravity_basis := Basis()
	## Transformasi dunia tulang penggantung saat ini. Dipakai untuk menyusun
	## bentuk rest (rotasi + LETAK: tanpa letak, kain tertarik ke titik nol dunia
	## sehingga tidak ikut saat badan berpindah).
	var anchor := Transform3D()
	## Kapsul yang relevan untuk rantai ini + mask "partikel ini di luar kapsul
	## saat rest" (1 = boleh ditolak keluar, 0 = memang tertanam).
	var colliders := PackedInt32Array()
	var allowed := PackedByteArray()
	var group := -1
	## Kekuatan jatuh ke arah gravitasi (lihat GROUPS).
	var hang := 0.0
	var stiffness := 20.0
	var drag := 2.0
	var gravity := 1.0
	var wind := 0.6
	var wind_drag := 2.4

	func size() -> int:
		return bones.size()


## Keterangan partikel paling dalam yang menembus kapsul (diisi
## `penetration_report()`), supaya gerbang bisa menunjuk rantai dan tulangnya.
var last_penetration := ""
## Keterangan terburuk untuk kain menembus kain lain (diisi `weave_report()`).
var last_weave := ""
var _chains: Array[Strand] = []
var _colliders: Array[Capsule] = []
var _skeleton: Skeleton3D
var _time := 0.0
var _iterations := 2
var _gravity := 9.8
var _wind_dir := Vector3(1.0, 0.0, 0.35)
var _wind_strength := 1.35
var _ground_y := 0.0
var _enabled := true
var _diagnostics := ""
var _warned := false


# ------------------------------------------------------------------ setup ----

## Bangun rantai + kapsul dari rest pose skeleton. Aman dipanggil ulang.
## Jumlah iterasi penjaga panjang/kekakuan/tabrakan per langkah. Mode ringan
## memakai 1 (cukup untuk kain yang sudah tenang), mode normal 2.
func set_iterations(value: int) -> void:
	_iterations = clampi(value, 1, 4)


func iteration_count() -> int:
	return _iterations


func configure(skeleton: Skeleton3D, iterations := 2) -> void:
	_skeleton = skeleton
	_iterations = clampi(iterations, 1, 4)
	_chains = []
	_colliders = []
	_diagnostics = ""
	_warned = false
	if skeleton == null:
		push_error("ClothSprings: skeleton kosong")
		return
	_build_colliders()
	var groups := _group_bones(skeleton)
	for group: int in range(GROUPS.size()):
		_build_group_chains(skeleton, group, groups[group])
	if _chains.is_empty() and not _warned:
		_warned = true
		push_error("ClothSprings: tidak ada tulang kain/rambut yang cocok")
	_build_weaves()
	_init_particles(skeleton)
	_diagnostics = "[cloth] %d rantai, %d tulang, %d kapsul" % [
		chain_count(), bone_count(), _colliders.size()]


## Kumpulkan tulang per grup. Tulang yang cocok dengan lebih dari satu prefix
## masuk ke grup pertama (urutan GROUPS menentukan prioritas).
func _group_bones(skeleton: Skeleton3D) -> Array[PackedInt32Array]:
	var groups: Array[PackedInt32Array] = []
	for _index in range(GROUPS.size()):
		groups.append(PackedInt32Array())
	for bone in range(skeleton.get_bone_count()):
		var key := Humanoid.normalize(skeleton.get_bone_name(bone))
		if _is_skipped(key):
			continue
		for group: int in range(GROUPS.size()):
			var prefix: String = GROUPS[group]["prefix"]
			if key.begins_with(Humanoid.normalize(prefix)):
				groups[group].append(bone)
				break
	return groups


## Tulang kain yang dipasang di lengan (lihat SKIP_BONES).
func _is_skipped(key: String) -> bool:
	for prefix: String in SKIP_BONES:
		if key.begins_with(Humanoid.normalize(prefix)):
			return true
	return false


func _build_group_chains(skeleton: Skeleton3D, group: int,
		bones: PackedInt32Array) -> void:
	if bones.is_empty():
		return
	var inside := {}
	for bone in bones:
		inside[bone] = true
	# Anak per tulang, dibatasi ke grup yang sama.
	var children := {}
	for bone in bones:
		var parent := skeleton.get_bone_parent(bone)
		if not inside.has(parent):
			continue
		if not children.has(parent):
			children[parent] = PackedInt32Array()
		var list: PackedInt32Array = children[parent]
		list.append(bone)
		children[parent] = list
	for bone in bones:
		var parent := skeleton.get_bone_parent(bone)
		if inside.has(parent):
			continue
		_grow_chain(skeleton, group, bone, children)


## Telusuri rantai lurus sampai bercabang/buntu; cabang memulai rantai baru.
func _grow_chain(skeleton: Skeleton3D, group: int, start: int, children: Dictionary) -> void:
	var bones := PackedInt32Array()
	var bone := start
	while bone >= 0:
		bones.append(bone)
		var kids: PackedInt32Array = children.get(bone, PackedInt32Array())
		if kids.size() != 1:
			for kid in kids:
				_grow_chain(skeleton, group, kid, children)
			break
		bone = kids[0]
	_build_chain(skeleton, group, bones)


func _build_chain(skeleton: Skeleton3D, group: int, bones: PackedInt32Array) -> void:
	var parent_bone := skeleton.get_bone_parent(bones[0])
	if parent_bone < 0:
		return
	var chain := Strand.new()
	chain.bones = bones
	chain.parent_bone = parent_bone
	chain.group = group
	var settings: Dictionary = GROUPS[group]
	chain.stiffness = float(settings["stiffness"])
	chain.hang = float(settings["hang"])
	chain.drag = float(settings["drag"])
	chain.gravity = float(settings["gravity"])
	chain.wind = float(settings["wind"])
	# Offset partikel di ruang rest tulang penggantung.
	var parent_rest := skeleton.get_bone_global_rest(parent_bone)
	var parent_inverse := parent_rest.affine_inverse()
	var rest_points := PackedVector3Array()
	for index in range(bones.size()):
		var rest := skeleton.get_bone_global_rest(bones[index])
		rest_points.append(rest.origin)
		chain.rest_local.append(parent_inverse * rest.origin)
	rest_points.append(_tip_point(skeleton, bones, rest_points))
	chain.rest_local.append(parent_inverse * rest_points[rest_points.size() - 1])
	chain.lengths.resize(rest_points.size())
	for index in range(1, rest_points.size()):
		chain.lengths[index] = rest_points[index].distance_to(rest_points[index - 1])
		if chain.lengths[index] < 0.0005:
			return # tulang bertumpuk: tidak ada yang bisa digoyangkan
	# Arah segmen di ruang masing-masing tulang + basis rest relatif induknya.
	for index in range(bones.size()):
		var rest := skeleton.get_bone_global_rest(bones[index])
		var direction := rest_points[index + 1] - rest_points[index]
		chain.dir_local.append((rest.basis.inverse() * direction).normalized())
		var above := skeleton.get_bone_global_rest(bones[index - 1]) if index > 0 else parent_rest
		chain.rel_basis.append(above.basis.inverse() * rest.basis)
	_attach_colliders(chain, rest_points)
	_chains.append(chain)


## Titik ujung rantai: tulang anak kalau ada (walau di luar grup, mis. "Nub"),
## kalau tidak ada diperkirakan dari panjang segmen terakhir.
func _tip_point(skeleton: Skeleton3D, bones: PackedInt32Array,
		rest_points: PackedVector3Array) -> Vector3:
	var last := bones[bones.size() - 1]
	for child in range(skeleton.get_bone_count()):
		if skeleton.get_bone_parent(child) == last:
			return skeleton.get_bone_global_rest(child).origin
	var tail := rest_points[rest_points.size() - 1]
	var previous := Vector3.ZERO
	if rest_points.size() >= 2:
		previous = rest_points[rest_points.size() - 2]
	else:
		# Rantai satu tulang (mis. satu helai rambut, anting, liontin): pakai
		# arah tulang induknya supaya ujungnya tidak jatuh tepat di pangkal
		# (dulu panjangnya jadi nol dan rantainya dibuang).
		var parent := skeleton.get_bone_parent(last)
		if parent < 0:
			return tail + Vector3(0.0, -0.03, 0.0)
		previous = skeleton.get_bone_global_rest(parent).origin
	var length := tail.distance_to(previous)
	if length < 0.0005:
		return tail + Vector3(0.0, -0.03, 0.0)
	return tail + (tail - previous).normalized() * length


func _build_colliders() -> void:
	for entry: Array in COLLIDERS:
		var bone_a := Humanoid.find_bone(_skeleton, entry[0])
		var bone_b := Humanoid.find_bone(_skeleton, entry[1])
		if bone_a < 0 or bone_b < 0:
			continue
		var collider := Capsule.new()
		collider.bone = bone_a
		collider.radius = float(entry[3])
		var rest_a := _skeleton.get_bone_global_rest(bone_a)
		var rest_b := _skeleton.get_bone_global_rest(bone_b)
		var tail: float = float(entry[2])
		collider.from_local = rest_a.affine_inverse() * rest_a.origin
		var end := rest_b.origin + (rest_b.origin - rest_a.origin) * tail
		collider.to_local = rest_a.affine_inverse() * end
		_colliders.append(collider)


## Pilih kapsul yang mungkin bersinggungan dengan rantai (dihitung sekali dari
## rest pose). Tanpa saringan ini tiap partikel harus diuji ke semua kapsul.
## `allowed` diisi per KAPSUL lalu per partikel, dan `_resolve()` membacanya
## dengan pola yang sama (kolom `slot`, baris `partikel`) — mask yang tertukar
## membuat simulasi mendorong partikel yang salah dan itulah sumber kain yang
## tetap menembus badan.
func _attach_colliders(chain: Strand, rest_points: PackedVector3Array) -> void:
	for index in range(_colliders.size()):
		var collider := _colliders[index]
		var rest_a := _skeleton.get_bone_global_rest(collider.bone)
		var from_point := rest_a * collider.from_local
		var to_point := rest_a * collider.to_local
		var nearest := INF
		for point in rest_points:
			nearest = minf(nearest, _distance_to_segment(point, from_point, to_point))
		if nearest > collider.radius + MAX_COLLIDER_MARGIN:
			continue
		chain.colliders.append(index)
		for point in rest_points:
			var distance := _distance_to_segment(point, from_point, to_point)
			chain.allowed.append(1 if distance >= collider.radius * 0.92 else 0)


# --------------------------------------------------------- kain vs kain -----

## Lapisan tiap rantai dari rest pose: rata-rata jarak titik-titik rantai ke
## kapsul badan terdekat. Makin besar nilainya, makin di luar posisinya.
func _chain_layer(index: int) -> float:
	var chain := _chains[index]
	var parent_rest := _skeleton.get_bone_global_rest(chain.parent_bone)
	var total := 0.0
	for value in chain.rest_local:
		var point := parent_rest * value
		var nearest := INF
		for collider in _colliders:
			if collider.chain >= 0:
				continue
			var rest_a := _skeleton.get_bone_global_rest(collider.bone)
			nearest = minf(nearest, _distance_to_segment(point, rest_a * collider.from_local,
				rest_a * collider.to_local))
		total += nearest
	return total / maxf(1.0, float(chain.rest_local.size()))


## Apakah grup ini ikut aturan lapisan kain-vs-kain.
func _group_weaves(group: int) -> bool:
	return GROUPS[group]["weave"] == true


## Bangun kapsul kain-vs-kain: hanya antara rantai yang BERBEDA lapisan, dan
## hanya untuk segmen yang memang berdekatan di rest pose (biaya per frame
## dijaga kecil, jadi tidak perlu menguji semua pasangan).
func _build_weaves() -> void:
	var layers := PackedFloat32Array()
	for index in range(_chains.size()):
		layers.append(_chain_layer(index))
	for target in range(_chains.size()):
		var chain := _chains[target]
		if not _group_weaves(chain.group):
			continue
		var slots: Array[int] = []
		for other in range(_chains.size()):
			if slots.size() >= MAX_WEAVE_CAPSULES:
				break
			if other == target or not _group_weaves(_chains[other].group):
				continue
			if layers[target] <= layers[other] + WEAVE_LAYER_EPS:
				continue # rantai ini bukan lapisan luar dari `other`
			_weave_pair(target, other, slots)
		for slot in slots:
			_attach_weave(chain, slot)


## Tambahkan kapsul dari segmen rantai `inner` yang paling dekat dengan rantai
## `outer` (sampai batas `MAX_WEAVE_CAPSULES` untuk seluruh rantai).
func _weave_pair(outer: int, inner: int, slots: Array[int]) -> void:
	var chain := _chains[inner]
	var parent_rest := _skeleton.get_bone_global_rest(chain.parent_bone)
	var points := PackedVector3Array()
	for value in chain.rest_local:
		points.append(parent_rest * value)
	var chosen := PackedInt32Array()
	var chosen_distance := PackedFloat32Array()
	for index in range(points.size() - 1):
		var distance := _chain_segment_distance(outer, points[index], points[index + 1])
		if distance > WEAVE_RADIUS + WEAVE_REACH:
			continue
		chosen.append(index)
		chosen_distance.append(distance)
	while not chosen.is_empty() and slots.size() < MAX_WEAVE_CAPSULES:
		var best := 0
		for index in range(1, chosen.size()):
			if chosen_distance[index] < chosen_distance[best]:
				best = index
		slots.append(_make_weave(chain, points, chosen[best], inner))
		chosen.remove_at(best)
		chosen_distance.remove_at(best)


## Jarak terdekat titik-titik rest rantai `index` ke satu segmen kain.
func _chain_segment_distance(index: int, from_point: Vector3, to_point: Vector3) -> float:
	var chain := _chains[index]
	var parent_rest := _skeleton.get_bone_global_rest(chain.parent_bone)
	var nearest := INF
	for value in chain.rest_local:
		nearest = minf(nearest, _distance_to_segment(parent_rest * value, from_point, to_point))
	return nearest


func _make_weave(chain: Strand, points: PackedVector3Array, index: int, inner: int) -> int:
	var bone := chain.bones[mini(index, chain.bones.size() - 1)]
	var rest := _skeleton.get_bone_global_rest(bone)
	var capsule := Capsule.new()
	capsule.bone = bone
	capsule.chain = inner
	capsule.radius = WEAVE_RADIUS
	capsule.from_local = rest.affine_inverse() * points[index]
	capsule.to_local = rest.affine_inverse() * points[index + 1]
	_colliders.append(capsule)
	return _colliders.size() - 1


## Kapsul kain tidak memakai mask "tertanam saat rest" seperti kapsul badan:
## rantai luar memang menempel pada rantai dalam, jadi lapisan luar selalu
## boleh didorong keluar. Urutan penulisannya harus sama dengan `_attach_colliders`.
func _attach_weave(chain: Strand, slot: int) -> void:
	chain.colliders.append(slot)
	for _point in chain.rest_local:
		chain.allowed.append(1)


func _init_particles(skeleton: Skeleton3D) -> void:
	for chain in _chains:
		var rigid := skeleton.global_transform * skeleton.get_bone_global_pose(chain.parent_bone)
		chain.gravity_basis = rigid.basis.orthonormalized()
		chain.anchor = rigid
		chain.points.resize(chain.rest_local.size())
		chain.prev.resize(chain.rest_local.size())
		for index in range(chain.rest_local.size()):
			var position := rigid * chain.rest_local[index]
			chain.points[index] = position
			chain.prev[index] = position


# ------------------------------------------------------------------ jalan ----

func step(delta: float, skeleton: Skeleton3D) -> void:
	if not _enabled or skeleton == null or _chains.is_empty():
		return
	var dt := clampf(delta, MIN_DELTA, MAX_DELTA)
	_time += dt
	_update_colliders(skeleton)
	var wind := _wind()
	var world := skeleton.global_transform
	for chain in _chains:
		_blend_basis(chain, world, skeleton, dt)
		_simulate_chain(chain, dt, world, skeleton, wind * chain.wind)
	for chain in _chains:
		_write_chain(chain, skeleton, world)


## Bentuk acuan rantai: posisi rest yang diambil dari tulang penggantung yang
## SEDANG beranimasi. Saat kepala menoleh, rambut ikut arah barunya; tetapi
## karena yang ditarik hanya sebagian tiap frame, ayunannya tetap terlihat.
func _blend_basis(chain: Strand, world: Transform3D, skeleton: Skeleton3D, dt: float) -> void:
	var rigid := world * skeleton.get_bone_global_pose(chain.parent_bone)
	var target := rigid.basis.orthonormalized()
	chain.gravity_basis = chain.gravity_basis.slerp(target,
		clampf(dt * BASIS_FOLLOW, 0.0, 1.0)).orthonormalized()
	if rigid.basis.determinant() < 0.0:
		chain.gravity_basis = target


func _simulate_chain(chain: Strand, dt: float, world: Transform3D, skeleton: Skeleton3D,
		wind: Vector3) -> void:
	var rigid := world * skeleton.get_bone_global_pose(chain.parent_bone)
	chain.anchor = rigid
	chain.points[0] = rigid * chain.rest_local[0]
	var damping := clampf(1.0 - chain.drag * dt, 0.0, 1.0)
	var accel := Vector3(0.0, -_gravity * chain.gravity, 0.0) + wind
	var offset := accel * dt * dt
	for index in range(1, chain.points.size()):
		var velocity := (chain.points[index] - chain.prev[index]) * damping
		# Angin mendorong kain sesuai kecepatan relatifnya: makin cepat kain
		# bergerak, makin kecil dorongan tambahannya — inilah yang membuat kain
		# "mengembang" saat berlari dan mengendur saat berhenti.
		velocity += (wind - velocity) * clampf(chain.wind_drag * dt, 0.0, 1.0)
		chain.prev[index] = chain.points[index]
		chain.points[index] = chain.points[index] + velocity + offset
	var step_k := 1.0 - exp(-chain.stiffness * dt / float(_iterations))
	for _iteration in range(_iterations):
		for index in range(1, chain.points.size()):
			_keep_length(chain, index)
			_keep_shape(chain, index, step_k)
			_resolve(chain, index, false)
			_resolve(chain, index, true)
		if _ground_y > -INF:
			for index in range(1, chain.points.size()):
				_keep_above_ground(chain, index, dt)
	# Tabrakan ditutup paling akhir: pembatas tanah dan penjaga panjang bisa
	# mendorong partikel masuk kembali ke kapsul, jadi keadaan akhir langkah harus
	# selalu bebas dari tembus badan. Kain-vs-kain didahulukan supaya dorongan
	# pemisahan lapisan tidak menarik partikel kembali ke dalam badan.
	for index in range(1, chain.points.size()):
		_resolve(chain, index, true)
		_resolve(chain, index, false)


## Panjang segmen: hanya partikel anak yang digeser (rantai "ikuti pemimpin"),
## cara paling stabil untuk kain yang menggantung.
func _keep_length(chain: Strand, index: int) -> void:
	var parent := chain.points[index - 1]
	var delta := chain.points[index] - parent
	var distance := delta.length()
	var target := chain.lengths[index]
	if distance < 0.0001:
		chain.points[index] = parent + Vector3(0.0, -target, 0.0)
		return
	chain.points[index] = parent + delta * (target / distance)


## Kekakuan: tarik partikel kembali ke tempat rest-nya, diukur dari tulang
## penggantung yang SEDANG beranimasi. Karena yang ditarik adalah POSISI (bukan
## cuma arah), rantai ikut menyesuaikan saat badan miring.
##
## Arah acuan tiap segmen diputar ke arah gravitasi sebesar `hang` (makin besar
## di ujung rantai). Inilah bedanya kain dengan papan: pose rest model ini
## membentangkan cape ke belakang, jadi tanpa `hang` penjaga bentuk selalu
## menariknya kembali ke sudut itu. Dengan `hang`, pangkal tetap mengikuti sudut
## rest (sambungan ke badan tidak patah) dan ujungnya jatuh ke bawah.
func _keep_shape(chain: Strand, index: int, k: float) -> void:
	if k <= 0.0:
		return
	var rest := chain.anchor.origin + chain.gravity_basis * chain.rest_local[index]
	var rest_offset := rest - chain.points[index - 1]
	var current := chain.points[index] - chain.points[index - 1]
	if chain.hang > 0.0 and rest_offset.length_squared() > 0.000001:
		var hang := chain.hang * _hang_ramp(chain, index)
		if hang > 0.0:
			rest_offset = rest_offset.normalized().slerp(Vector3.DOWN, hang) \
				* rest_offset.length()
	chain.points[index] = chain.points[index - 1] + current.lerp(rest_offset, k)


## Berapa besar bagian rantai ini ikut jatuh: 0 di pangkal, 1 di ujung.
func _hang_ramp(chain: Strand, index: int) -> float:
	var count := chain.points.size() - 1
	if count <= 1:
		return 1.0
	return smoothstep(HANG_RAMP_FROM, 1.0, float(index) / float(count))


## Dorong partikel keluar dari kapsul. `weaves_only` memilih kapsul kain
## (bukan kapsul badan). Mask dibaca per KAPSUL lalu per partikel — sama seperti
## urutan penulisannya di `_attach_colliders`/`_attach_weave`.
func _resolve(chain: Strand, index: int, weaves_only: bool) -> void:
	var count := chain.colliders.size()
	for slot in range(count):
		if chain.allowed[slot * chain.points.size() + index] == 0:
			continue
		var collider := _colliders[chain.colliders[slot]]
		if (collider.chain >= 0) != weaves_only:
			continue
		var closest := _closest_on_segment(chain.points[index], collider.from_world,
			collider.to_world)
		var delta := chain.points[index] - closest
		var distance := delta.length()
		if distance >= collider.radius or distance < 0.00001:
			continue
		chain.points[index] = closest + delta * (collider.radius / distance)


func _keep_above_ground(chain: Strand, index: int, dt: float) -> void:
	if chain.points[index].y < _ground_y:
		chain.points[index].y = _ground_y
	# Gesekan tanah: laju mendatar diserap supaya kain tidak meluncur bebas.
	# Kecepatan dihitung ulang dari selisih partikel supaya gesekannya benar
	# walau beberapa iterasi berjalan dalam satu langkah.
	var friction := clampf(GROUND_FRICTION * dt, 0.0, 1.0)
	var velocity := chain.points[index] - chain.prev[index]
	velocity.x *= 1.0 - friction
	velocity.z *= 1.0 - friction
	chain.prev[index] = chain.points[index] - velocity


## Tulis hasil simulasi ke pose tulang. Rotasi dihitung dari selisih arah:
## basis tulang = (rotasi dari arah rest ke arah partikel) x basis animasinya.
## Kedua tulang memakai rumus yang sama supaya tidak ada patahan di sambungan;
## karena arahnya diteruskan dari tulang sebelumnya, tidak ada gaya ganda.
func _write_chain(chain: Strand, skeleton: Skeleton3D, world: Transform3D) -> void:
	var inverse_world := world.affine_inverse()
	for index in range(chain.bones.size()):
		var above := chain.parent_bone if index == 0 else chain.bones[index - 1]
		var parent_pose := skeleton.get_bone_global_pose(above)
		var base := parent_pose.basis * chain.rel_basis[index]
		var direction := chain.points[index + 1] - chain.points[index]
		var target := (base * chain.dir_local[index]).normalized()
		if direction.length_squared() > 0.0000001:
			var rotation := _rotation_between(target, direction.normalized())
			base = rotation * base
		var pose := inverse_world * Transform3D(base, chain.points[index])
		var local := parent_pose.affine_inverse() * pose
		skeleton.set_bone_pose_position(chain.bones[index], local.origin)
		skeleton.set_bone_pose_rotation(chain.bones[index], local.basis.get_rotation_quaternion())


## Laporan tembus badan: x = jumlah rantai yang tidak punya kapsul badan sama
## sekali (rantai seperti itu pasti menembus badan saat bergerak), y = kedalaman
## tembus terburuk dalam meter (0 kalau tidak ada). Partikel yang memang
## tertanam di rest pose (allowed = 0) dilewati. Dipakai gerbang supaya "kain
## menembus badan" jadi angka, bukan pendapat.
func penetration_report() -> Vector2:
	var worst := 0.0
	var uncovered := 0
	for chain in _chains:
		var bodies := 0
		for slot in chain.colliders:
			if _colliders[slot].chain < 0:
				bodies += 1
		if bodies == 0:
			uncovered += 1
		worst = maxf(worst, _penetration_depth(chain, false))
	return Vector2(uncovered, worst)


## Kedalaman kain menembus KAIN LAIN (aturan lapisan). Dipakai gerbang supaya
## "nembus baju lain" juga jadi angka.
func weave_report() -> float:
	var worst := 0.0
	for chain in _chains:
		worst = maxf(worst, _penetration_depth(chain, true))
	return worst


func _penetration_depth(chain: Strand, weaves_only: bool) -> float:
	var worst := 0.0
	var slots := chain.colliders.size()
	for index in range(1, chain.points.size()):
		for slot in range(slots):
			if chain.allowed[slot * chain.points.size() + index] == 0:
				continue
			var collider := _colliders[chain.colliders[slot]]
			if (collider.chain >= 0) != weaves_only:
				continue
			var closest := _closest_on_segment(chain.points[index],
				collider.from_world, collider.to_world)
			var depth := collider.radius - chain.points[index].distance_to(closest)
			if depth <= worst:
				continue
			worst = depth
			var against := "kapsul " + _skeleton.get_bone_name(collider.bone)
			if weaves_only:
				against = "kain rantai %d" % collider.chain
			var detail := "grup %d partikel %d (%s) vs %s" % [chain.group, index,
				_skeleton.get_bone_name(chain.bones[chain.bones.size() - 1]), against]
			if weaves_only:
				last_weave = detail
			else:
				last_penetration = detail
	return worst


func _update_colliders(skeleton: Skeleton3D) -> void:
	for collider in _colliders:
		var pose := skeleton.global_transform * skeleton.get_bone_global_pose(collider.bone)
		collider.from_world = pose * collider.from_local
		collider.to_world = pose * collider.to_local


func _wind() -> Vector3:
	if _wind_strength <= 0.0:
		return Vector3.ZERO
	var direction := _wind_dir.normalized().rotated(Vector3.UP, sin(_time * 0.23) * 0.6)
	var gust := 0.55 + 0.45 * sin(_time * 1.7) * sin(_time * 0.41)
	return direction * (_wind_strength * gust)


# ---------------------------------------------------------------- bantuan ----

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


static func _closest_on_segment(point: Vector3, from_point: Vector3, to_point: Vector3) -> Vector3:
	var segment := to_point - from_point
	var length_squared := segment.length_squared()
	if length_squared < 0.0000001:
		return from_point
	var t := clampf((point - from_point).dot(segment) / length_squared, 0.0, 1.0)
	return from_point + segment * t


static func _distance_to_segment(point: Vector3, from_point: Vector3, to_point: Vector3) -> float:
	return point.distance_to(_closest_on_segment(point, from_point, to_point))


# ------------------------------------------------------------------ API ------

func set_enabled(value: bool) -> void:
	_enabled = value


func set_wind(strength: float, direction: Vector3) -> void:
	_wind_strength = maxf(strength, 0.0)
	if direction.length_squared() > 0.000001:
		_wind_dir = direction.normalized()


func set_ground_height(value: float) -> void:
	_ground_y = value


func chain_count() -> int:
	return _chains.size()


func bone_count() -> int:
	var total := 0
	for chain in _chains:
		total += chain.bones.size()
	return total


func collider_count() -> int:
	return _colliders.size()


func _group_of(chain_index: int) -> int:
	if chain_index < 0 or chain_index >= _chains.size():
		return -1
	return _chains[chain_index].group


func chain_bones(chain_index: int) -> PackedInt32Array:
	if chain_index < 0 or chain_index >= _chains.size():
		return PackedInt32Array()
	return _chains[chain_index].bones


func chain_bone_names(chain_index: int) -> PackedStringArray:
	var names := PackedStringArray()
	if chain_index < 0 or chain_index >= _chains.size() or _skeleton == null:
		return names
	for bone in _chains[chain_index].bones:
		names.append(_skeleton.get_bone_name(bone))
	return names


func particle(chain_index: int, index: int) -> Vector3:
	if chain_index < 0 or chain_index >= _chains.size():
		return Vector3.ZERO
	var chain := _chains[chain_index]
	if index < 0 or index >= chain.points.size():
		return Vector3.ZERO
	return chain.points[index]


func chain_length(chain_index: int) -> float:
	if chain_index < 0 or chain_index >= _chains.size():
		return 0.0
	var total := 0.0
	var chain := _chains[chain_index]
	for index in range(1, chain.lengths.size()):
		total += chain.lengths[index]
	return total


## Contoh nama tulang yang cocok dengan grup mana pun — dipakai log/tes untuk
## membuktikan pola nama dari importer FBX benar-benar ketemu.
func bone_name_sample(limit := 24) -> PackedStringArray:
	var names := PackedStringArray()
	if _skeleton == null:
		return names
	for chain in _chains:
		if names.size() >= limit:
			break
		for bone in chain.bones:
			if names.size() >= limit:
				break
			names.append(_skeleton.get_bone_name(bone))
	return names


func render_diagnostics() -> String:
	return _diagnostics


## Ringkasan untuk log/tes: berapa rantai per grup.
func group_report() -> String:
	var counts := PackedInt32Array()
	counts.resize(GROUPS.size())
	for chain in _chains:
		if chain.group >= 0:
			counts[chain.group] += 1
	var parts := PackedStringArray()
	for group: int in range(GROUPS.size()):
		if counts[group] > 0:
			parts.append("%s=%d" % [GROUPS[group]["prefix"], counts[group]])
	return ", ".join(parts)
