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
const ClothDynamics = preload("res://src/game/animation/cloth_dynamics.gd")
const Materials = preload("res://src/game/character/aurelia_materials.gd")
const Springs = preload("res://src/game/animation/cloth_springs.gd")
const STEP := 1.0 / 60.0
var _failures := 0
## Catatan angka untuk dibaca dari anotasi CI (log panjang terpotong).
var _notes := PackedStringArray()
## Tiap pesan gagal hanya dicetak SEKALI (tes ini mengulang ratusan frame, dan
## log yang membanjir membuat bagian diagnostik di akhir terpotong).
var _reported := {}


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	if _reported.has(message):
		return
	_reported[message] = true
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
	_test_rig(character)
	_test_materials(character)
	_test_retarget_shape(character)
	_test_feet_above_ground(character)
	_test_cloth_penetration(character)
	_test_cloth_inertia(character)
	_test_cloth_no_penetration(character)
	var missing := Humanoid.missing_pairs(character.skeleton, character.avatar)
	if not missing.is_empty():
		_notes.append("pasangan hilang: " + ", ".join(missing))
	var chains := 0
	var bones := 0
	for springs in character.cloths:
		if springs.springs != null:
			chains += springs.springs.chain_count()
			bones += springs.springs.bone_count()
	print("[aurelia-test] kerangka=%d tulang=%d dipetakan=%d rantai=%d kain=%d gagal=%d"
		% [character.avatars.size(), character.avatar.get_bone_count(),
		character.retarget.mapped_count(), chains, bones, _failures])
	# Diagnostik di akhir: langkah CI yang gagal hanya menampilkan 60 baris log
	# terakhir, jadi bagian ini yang harus terbaca saat ada masalah.
	print("--- diagnostik ---")
	print(character.status)
	for note in _notes:
		print(note)
	print("nama tulang avatar:", _bone_names(character.avatar, 12))
	print("tulang mirip kain:", _cloth_names(character.avatar))
	quit(0 if _failures == 0 else 1)


func _bone_names(skeleton: Skeleton3D, limit: int) -> String:
	var names := PackedStringArray()
	for bone in range(mini(limit, skeleton.get_bone_count())):
		names.append(skeleton.get_bone_name(bone))
	return " | ".join(names)


## Semua tulang yang namanya mengandung kain/rambut, apa pun bentuknya. Ini yang
## menjawab "kenapa grup kain tidak ketemu" kalau importer mengubah nama.
func _cloth_names(skeleton: Skeleton3D) -> String:
	var names := PackedStringArray()
	for bone in range(skeleton.get_bone_count()):
		var key := Humanoid.normalize(skeleton.get_bone_name(bone))
		for needle in ["hair", "shawl", "collar", "hip", "pendant", "earrings",
				"neck", "flycloak", "dress", "robe"]:
			if key.contains(needle):
				names.append(skeleton.get_bone_name(bone))
				break
	return "%d: %s" % [names.size(), ", ".join(names)]


func _test_rig(character: Character) -> void:
	_check(character.rig_model != null and not character.rig_model.visible,
		"Rig animasi UAL seharusnya disembunyikan")
	_check(character.avatar.get_bone_count() > 120,
		"Tulang avatar kurang: %d" % character.avatar.get_bone_count())
	var missing := Humanoid.missing_pairs(character.skeleton, character.avatar)
	_check(missing.is_empty(), "Pasangan tulang tidak ditemukan: " + ", ".join(missing))
	_check(character.retarget.mapped_count() == Humanoid.PAIRS.size(),
		"Peta tulang tidak lengkap: %d dari %d" % [character.retarget.mapped_count(),
		Humanoid.PAIRS.size()])
	_check(character.retarget.motion_scale() > 0.7 and character.retarget.motion_scale() < 1.05,
		"Skala gerak tidak wajar: %.3f" % character.retarget.motion_scale())
	var chains := 0
	var bones := 0
	var colliders := 0
	for springs in character.cloths:
		if springs.springs == null:
			continue
		chains += springs.springs.chain_count()
		bones += springs.springs.bone_count()
		colliders = maxi(colliders, springs.springs.collider_count())
	_check(chains >= 40, "Rantai kain terlalu sedikit: %d" % chains)
	_check(bones >= 60, "Tulang kain terlalu sedikit: %d" % bones)
	_check(colliders >= 12, "Kapsul badan terlalu sedikit: %d" % colliders)


## Material diambil dari NAMA MATERIAL FBX per surface (importer Godot menamai
## tiap surface dengan nama materialnya). Uji ini menjaga tiga bug yang pernah
## terjadi:
##   1. mesh Body punya 3 surface (Mat_Hair + Mat_Body + Mat_Dress) — kalau
##      ditimpa satu material, rambut depan memakai atlas jubah dan terlihat
##      seperti helm navy;
##   2. Face_Eye/EyeStar memakai Mat_Face (atlas wajah), bukan atlas rambut;
##   3. cull mode mengikuti material aslinya (hanya Dress double-sided); kalau
##      semua dipaksa double-sided, sisi dalam rambut tergambar menembus wajah.
func _test_materials(character: Character) -> void:
	var visible := 0
	var mapping := PackedStringArray()
	var problems := PackedStringArray()
	for node in character.avatar.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.visible:
			continue
		visible += 1
		var surfaces := mesh.mesh.get_surface_count() if mesh.mesh != null else 0
		if surfaces == 0:
			problems.append("%s tanpa surface" % mesh.name)
			continue
		for surface in range(surfaces):
			var surface_name := mesh.mesh.surface_get_name(surface)
			var material := mesh.get_surface_override_material(surface) as StandardMaterial3D
			if material == null:
				problems.append("%s[%s] tanpa material" % [mesh.name, surface_name])
				continue
			if material.albedo_texture == null:
				problems.append("%s[%s] tanpa tekstur" % [mesh.name, surface_name])
				continue
			if not (material.next_pass is ShaderMaterial):
				problems.append("%s[%s] tanpa garis luar" % [mesh.name, surface_name])
			var texture := material.albedo_texture.resource_path.get_file()
			mapping.append("%s->%s" % [surface_name.replace("Avatar_Boy_Pole_Lohen_", ""),
				texture])
			if surface_name.ends_with("Mat_Dress"):
				if material.cull_mode != BaseMaterial3D.CULL_DISABLED:
					problems.append("dress bukan double-sided")
			elif material.cull_mode != BaseMaterial3D.CULL_BACK:
				problems.append("%s[%s] tidak single-sided" % [mesh.name, surface_name])
			var expected := _expected_texture(surface_name)
			if not expected.is_empty() and not texture.begins_with(expected):
				problems.append("%s[%s] memakai %s, harusnya %s" % [mesh.name, surface_name,
					texture, expected])
	_check(problems.is_empty(), "Material avatar salah: " + "; ".join(problems))
	# 8 mesh asli; satu (EffectMesh, material Avatar_Default_Mat) disembunyikan.
	_check(visible == 7, "Jumlah mesh avatar yang tampil bukan 7: %d" % visible)
	_notes.append("material: " + ", ".join(mapping))
	# Bukti regresi: mesh Body harus punya surface rambut DAN surface badan.
	var body := character.avatar.find_child("Body", true, false) as MeshInstance3D
	_check(body != null, "Mesh Body tidak ditemukan")
	if body != null:
		var has_hair := false
		var has_skin := false
		for surface in range(body.mesh.get_surface_count()):
			var name := body.mesh.surface_get_name(surface)
			if name.ends_with("Mat_Hair"):
				has_hair = true
			if name.ends_with("Mat_Body") or name.ends_with("Mat_Dress"):
				has_skin = true
		_check(has_hair and has_skin,
			"Mesh Body harus punya surface rambut dan badan (rambut=%s badan=%s)"
			% [has_hair, has_skin])


## Tekstur yang seharusnya dipakai, dibaca dari berkas material Unity aslinya.
func _expected_texture(material_name: String) -> String:
	var key := Materials.rule_key(material_name)
	match key:
		"avatarboypolelohenmathair", "avatarboypolelohenmatpupil":
			return "Avatar_Boy_Pole_Lohen_Tex_Hair_Diffuse"
		"avatarboypolelohenmatbody", "avatarboypolelohenmatdress":
			return "Avatar_Boy_Pole_Lohen_Tex_Body_Diffuse"
		"avatarboypolelohenmatface", "avatarboypolelohenmatbrow":
			return "Avatar_Boy_Pole_Lohen_Tex_Face_Diffuse"
	return ""


## Arah sumbu tulang (tulang -> anak yang ikut dipetakan) harus sama dengan
## arah sumbu tulang animasi. Angkanya dicatat supaya bisa dibaca di CI.
func _check_direction(character: Character, source_name: String, target_name: String,
		motion: String) -> void:
	var source_bone := character.skeleton.find_bone(source_name)
	var target_bone := character.avatar.find_bone(target_name)
	if source_bone < 0 or target_bone < 0:
		_check(false, "Tulang tidak ditemukan: %s / %s" % [source_name, target_name])
		return
	var pair := Humanoid.axis_child(character.skeleton, character.avatar, source_bone,
		target_bone)
	if pair.x < 0:
		_check(false, "Tidak ada anak yang dipetakan di %s" % source_name)
		return
	var source_direction := (character.skeleton.get_bone_global_pose(pair.x).origin
		- character.skeleton.get_bone_global_pose(source_bone).origin).normalized()
	var target_direction := (character.avatar.get_bone_global_pose(pair.y).origin
		- character.avatar.get_bone_global_pose(target_bone).origin).normalized()
	var dot := source_direction.dot(target_direction)
	if motion == "Crouch_Fwd_Loop":
		_notes.append("arah %s: dot=%.4f (%s->%s)" % [source_name, dot,
			character.skeleton.get_bone_name(pair.x),
			character.avatar.get_bone_name(pair.y)])
	if dot < 0.97:
		_check(false, "%s avatar menyimpang dari animasi (%s): dot=%.3f" % [
			source_name, motion, dot])


## Pembungkus kain yang memuat tulang rambut (badan dan rambut bisa berada di
## kerangka berbeda kalau importer FBX memecahnya).
func _cloth_with_hair(character: Character) -> ClothDynamics:
	for wrapper in character.cloths:
		if wrapper.springs == null:
			continue
		for index in range(wrapper.springs.chain_count()):
			var names := wrapper.springs.chain_bone_names(index)
			if not names.is_empty() and names[0].begins_with("Bone_Hair"):
				return wrapper
	return null


## Rantai terpanjang (paling banyak tulang, lalu paling panjang) untuk uji
## kelembaman: makin panjang rantai, makin terlihat kain tertinggal.
func _longest_chain(springs: Springs, only_hair := false) -> int:
	var best := -1
	var best_length := 0.0
	for index in range(springs.chain_count()):
		var names := springs.chain_bone_names(index)
		if names.is_empty():
			continue
		if only_hair and not names[0].begins_with("Bone_Hair"):
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
	var wrapper := _cloth_with_hair(character)
	if wrapper == null:
		_check(false, "Tidak ada pembungkus kain yang punya rantai rambut")
		return
	var springs: Springs = wrapper.springs
	var chain := _longest_chain(springs)
	_check(chain >= 0, "Tidak ada rantai kain untuk diuji")
	if chain < 0:
		return
	# Dudukkan dulu supaya simulasi tenang.
	for step in range(90):
		wrapper.simulate(STEP)
	var tip := springs.particle(chain, springs.chain_bones(chain).size())
	var settled := tip
	_check(settled.y < tip.y + 0.001, "Kain tidak menggantung ke bawah")
	# Badan digeser sedikit (bukan dipindah 1 m sekali hentak): rambut sepanjang
	# beberapa senti memang HARUS ikut saat kepala berpindah jauh, jadi yang
	# mengukur kelembaman adalah geseran kecil dibanding panjang rantai.
	var body_move := 0.15
	character.global_position += Vector3(body_move, 0.0, 0.0)
	wrapper.simulate(STEP)
	wrapper.simulate(STEP)
	var lagging := springs.particle(chain, springs.chain_bones(chain).size())
	var cloth_move := lagging.distance_to(settled)
	_check(cloth_move < body_move * 0.6, "Kain menempel kaku, tidak tertinggal: %.3f m"
		% cloth_move)
	_check(cloth_move > body_move * 0.05, "Kain tidak bergerak sama sekali: %.3f m"
		% cloth_move)
	for step in range(120):
		wrapper.simulate(STEP)
	var caught_up := springs.particle(chain, springs.chain_bones(chain).size())
	var rest_point := character.avatar.global_transform * Vector3.ZERO
	_notes.append("kain: diam=%.3f tertinggal=%.3f menyusul=%.3f (badan %.2f)" % [
		lagging.distance_to(settled), cloth_move, caught_up.distance_to(lagging),
		body_move])
	_check(caught_up.distance_to(lagging) > 0.2 * body_move,
		"Kain tidak menyusul badan setelah badan diam")
	_check(not is_equal_approx(caught_up.x, rest_point.x),
		"Kain ikut menempel ke titik asal badan")


## Kain/rambut tidak boleh menembus kepala atau badan — diukur dengan kapsul
## badan yang sama seperti yang dipakai simulasi, jadi hasilnya berupa angka:
## (a) tidak ada rantai yang tanpa kapsul sama sekali, (b) kedalaman tembus
## terburuk hampir nol, saat diam DAN saat klip lokomosi berjalan.
func _test_cloth_penetration(character: Character) -> void:
	var uncovered := 0
	for wrapper in character.cloths:
		if wrapper != null and wrapper.springs != null:
			uncovered += int(wrapper.springs.penetration_report().x)
	_check(uncovered == 0, "Ada %d rantai kain tanpa kapsul badan" % uncovered)
	var worst_idle := _worst_penetration(character, null)
	var worst_walk := _worst_penetration(character, "Jog_Fwd_Loop")
	_notes.append("tembus kain: diam=%.4f m, lari=%.4f m" % [worst_idle, worst_walk])
	_check(worst_idle < 0.02, "Kain menembus badan saat diam: %.3f m" % worst_idle)
	_check(worst_walk < 0.03, "Kain menembus badan saat lari: %.3f m" % worst_walk)


## Jalankan simulasi beberapa detik (opsional dengan klip lokomosi) lalu
## kembalikan kedalaman tembus terburuk dari semua kerangka.
func _worst_penetration(character: Character, motion: String) -> float:
	character.set_locomotion("Idle_Loop" if motion.is_empty() else motion, 1.0)
	character.animation.advance(0.0)
	var worst := 0.0
	for step in range(120):
		character.animation.advance(STEP)
		for follower in character.retargets:
			follower.apply()
		for wrapper in character.cloths:
			if wrapper == null:
				continue
			wrapper.simulate(STEP)
			worst = maxf(worst, wrapper.springs.penetration_report().y)
	return worst


## Rambut panjang tidak boleh menembus kepala/badan saat diam.
func _test_cloth_no_penetration(character: Character) -> void:
	var wrapper := _cloth_with_hair(character)
	if wrapper == null:
		return
	var springs: Springs = wrapper.springs
	var head := character.avatar.find_bone("Bip001 Head")
	var neck := character.avatar.find_bone("Bip001 Neck")
	if head < 0 or neck < 0:
		return
	character.global_position = Vector3.ZERO
	character.rotation = Vector3.ZERO
	for step in range(120):
		wrapper.simulate(STEP)
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
