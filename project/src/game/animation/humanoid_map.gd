extends RefCounted
## Peta tulang dari rig animasi UAL (nama gaya Unreal: "spine_01", "thigh_l")
## ke kerangka avatar Aurelia (nama gaya Biped: "Bip001 Spine", "Bip001 L Thigh").
##
## Kenapa perlu peta: klip UAL hanya menyebut tulang milik rig mannequin. Avatar
## punya nama tulang yang sama sekali berbeda, jadi tanpa peta ini tidak ada satu
## pun klip yang menggerakkan badannya (badan akan berdiri kaku seperti patung).
##
## Nama tulang SELALU dibandingkan dalam bentuk ternormalisasi (hanya huruf/angka,
## huruf kecil). Importer FBX boleh mengubah spasi, garis bawah, atau membuang
## tanda "+", jadi pencocokan mentah terlalu rapuh untuk diandalkan.

## Pasangan [nama tulang rig UAL, nama tulang avatar].
## Urutan tidak penting; yang penting setiap tulang avatar yang butuh gerakan
## punya pasangannya. Tulang jari ikut dipetakan supaya tangan tidak mengepal
## kaku saat klip membuka/menutup jari.
const PAIRS := [
	["pelvis", "Bip001 Pelvis"],
	["spine_01", "Bip001 Spine"],
	["spine_02", "Bip001 Spine1"],
	["spine_03", "Bip001 Spine2"],
	["neck_01", "Bip001 Neck"],
	["Head", "Bip001 Head"],
	["clavicle_l", "Bip001 L Clavicle"],
	["upperarm_l", "Bip001 L UpperArm"],
	["lowerarm_l", "Bip001 L Forearm"],
	["hand_l", "Bip001 L Hand"],
	["clavicle_r", "Bip001 R Clavicle"],
	["upperarm_r", "Bip001 R UpperArm"],
	["lowerarm_r", "Bip001 R Forearm"],
	["hand_r", "Bip001 R Hand"],
	["thigh_l", "Bip001 L Thigh"],
	["calf_l", "Bip001 L Calf"],
	["foot_l", "Bip001 L Foot"],
	["ball_l", "Bip001 L Toe0"],
	["thigh_r", "Bip001 R Thigh"],
	["calf_r", "Bip001 R Calf"],
	["foot_r", "Bip001 R Foot"],
	["ball_r", "Bip001 R Toe0"],
	# Jari: Biped menomori Finger0..Finger4 dengan Finger0 = jempol (paling pendek
	# dan paling "menyilang" di rest pose), Finger4 = kelingking.
	["thumb_01_l", "Bip001 L Finger0"],
	["thumb_02_l", "Bip001 L Finger01"],
	["thumb_03_l", "Bip001 L Finger02"],
	["index_01_l", "Bip001 L Finger1"],
	["index_02_l", "Bip001 L Finger11"],
	["index_03_l", "Bip001 L Finger12"],
	["middle_01_l", "Bip001 L Finger2"],
	["middle_02_l", "Bip001 L Finger21"],
	["middle_03_l", "Bip001 L Finger22"],
	["ring_01_l", "Bip001 L Finger3"],
	["ring_02_l", "Bip001 L Finger31"],
	["ring_03_l", "Bip001 L Finger32"],
	["pinky_01_l", "Bip001 L Finger4"],
	["pinky_02_l", "Bip001 L Finger41"],
	["pinky_03_l", "Bip001 L Finger42"],
	["thumb_01_r", "Bip001 R Finger0"],
	["thumb_02_r", "Bip001 R Finger01"],
	["thumb_03_r", "Bip001 R Finger02"],
	["index_01_r", "Bip001 R Finger1"],
	["index_02_r", "Bip001 R Finger11"],
	["index_03_r", "Bip001 R Finger12"],
	["middle_01_r", "Bip001 R Finger2"],
	["middle_02_r", "Bip001 R Finger21"],
	["middle_03_r", "Bip001 R Finger22"],
	["ring_01_r", "Bip001 R Finger3"],
	["ring_02_r", "Bip001 R Finger31"],
	["ring_03_r", "Bip001 R Finger32"],
	["pinky_01_r", "Bip001 R Finger4"],
	["pinky_02_r", "Bip001 R Finger41"],
	["pinky_03_r", "Bip001 R Finger42"],
]


## Buang spasi, garis bawah, tanda "+" dan lain-lain; sisakan huruf/angka kecil.
## "Bip001 L Thigh", "+FlycloakRootB CB A01" -> "bip001lthigh", "flycloakrootbcba01"
static func normalize(bone_name: String) -> String:
	var out := ""
	var lower := bone_name.to_lower()
	for index in range(lower.length()):
		var code := lower.unicode_at(index)
		if (code >= 97 and code <= 122) or (code >= 48 and code <= 57):
			out += String.chr(code)
	return out


## Cari tulang: nama persis dulu (cepat), lalu bentuk ternormalisasi.
## Mengembalikan -1 kalau tidak ada.
static func find_bone(skeleton: Skeleton3D, want: String) -> int:
	if skeleton == null or want.is_empty():
		return -1
	var direct := skeleton.find_bone(want)
	if direct >= 0:
		return direct
	var key := normalize(want)
	for index in range(skeleton.get_bone_count()):
		if normalize(skeleton.get_bone_name(index)) == key:
			return index
	return -1


## Nama pasangan yang TIDAK ditemukan, untuk pesan kesalahan yang jelas.
static func missing_pairs(source: Skeleton3D, target: Skeleton3D) -> PackedStringArray:
	var missing := PackedStringArray()
	for pair: Array in PAIRS:
		if find_bone(source, pair[0]) < 0 or find_bone(target, pair[1]) < 0:
			missing.append("%s -> %s" % [pair[0], pair[1]])
	return missing


## "Sumbu" tulang: anak langsungnya yang punya pasangan, dan pasangannya juga
## anak langsung tulang target. Inilah arah yang dipakai retarget dan yang harus
## sama persis antara animasi dan avatar; tes memakainya supaya mengukur hal yang
## sama (anak pertama biasa bisa tulang puntir atau tulang hias).
## Urutannya SAMA dengan retarget_modifier._measure(): anak dengan indeks tulang
## terkecil. Kalau urutannya berbeda, tes bisa mengukur jari manis sementara
## retarget mengarahkan jari telunjuk (selisih 30 derajat yang menyesatkan).
static func axis_child(source: Skeleton3D, target: Skeleton3D, source_bone: int,
		target_bone: int) -> Vector2i:
	if source == null or target == null:
		return Vector2i(-1, -1)
	var pairs := {}
	for pair: Vector2i in resolve(source, target):
		pairs[pair.x] = pair.y
	for child in range(source.get_bone_count()):
		if source.get_bone_parent(child) != source_bone:
			continue
		if not pairs.has(child):
			continue
		var target_child: int = pairs[child]
		if target.get_bone_parent(target_child) != target_bone:
			continue
		return Vector2i(child, target_child)
	return Vector2i(-1, -1)


## Peta nama rig sumber -> indeks tulang avatar, hanya pasangan yang ADA di
## kedua sisi. Dipakai retarget (gerak badan) dan goyangan kain (tulang gantung).
static func resolve(source: Skeleton3D, target: Skeleton3D) -> Array[Vector2i]:
	var resolved: Array[Vector2i] = []
	for pair: Array in PAIRS:
		var source_name: String = pair[0]
		var target_name: String = pair[1]
		var source_bone := find_bone(source, source_name)
		var target_bone := find_bone(target, target_name)
		if source_bone < 0 or target_bone < 0:
			continue
		resolved.append(Vector2i(source_bone, target_bone))
	return resolved
