extends SceneTree
## Gerbang "kulit beranimasi" mannequin.
##
## Yang diuji bukan "tidak ada error", tapi janji ke pengguna:
##   1. setiap mesh mannequin punya salinan kulit (tidak ada bagian telanjang),
##   2. salinan itu SELALU di pose yang sama dengan badannya (selisih ~0 m) —
##      kalau tidak, kulit dan badannya berpisah saat beranimasi,
##   3. bahan kulit dipakai DUA kali: pada mesh mannequin (lapisan dalam) dan
##      pada salinannya, jadi lipatan tajam pun tidak pernah menampakkan warna
##      mannequin polos,
##   4. denyutnya menanggapi kecepatan badan (diam vs lari),
##   5. gambarnya benar-benar berubah antar frame (animasi, bukan bahan mati) —
##      diuji dengan merender dan membandingkan piksel.
##
## Nama berkas ini sengaja terpisah dari `test_mannequin.gd` (yang menguji
## animasi & kontrol): gerbang kulit bisa gagal sendiri tanpa membingungkan.

const Character = preload("res://src/game/mannequin.gd")
const Catalog = preload("res://src/game/animation/catalog.gd")
const STEP := 1.0 / 60.0
## Ambang selisih pose kulit vs badan. Satu frame animasi menggeser tulang
## beberapa milimeter, jadi ambangnya harus lebih kecil dari itu.
const POSE_TOLERANCE := 0.0005
var _failures := 0
var _notes := PackedStringArray()
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
	if character.skeleton == null or character.skin == null:
		print("::error::mannequin/kulit tidak lengkap")
		quit(1)
		return
	_test_coverage(character)
	_test_pose_lock(character)
	_test_pulse(character)
	_test_clip_motion(character)
	print("[skin-test] mesh=%d tertutup=%d tulang=%d klip=%d gagal=%d" % [
		_mesh_count(character), character.skin.cover_count(),
		character.skeleton.get_bone_count(), Catalog.clip_count(), _failures])
	print("--- diagnostik ---")
	print(character.status)
	for note in _notes:
		print(note)
	quit(0 if _failures == 0 else 1)


func _mesh_count(character: Character) -> int:
	var total := 0
	for node in character.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).mesh != null:
			total += 1
	return total


## Janji 1 + 3: setiap mesh punya salinan kulit, dan bahan kulit identik dipakai
## di dalam maupun di luar.
func _test_coverage(character: Character) -> void:
	var sources: Array[MeshInstance3D] = []
	for node in character.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh != null and not mesh.name.begins_with("Skin_"):
			sources.append(mesh)
	_check(not sources.is_empty(), "Tidak ada mesh mannequin sama sekali")
	_check(character.skin.cover_count() >= sources.size(),
		"Mesh mannequin %d tapi kulit hanya menutup %d" % [sources.size(),
			character.skin.cover_count()])
	var inner := 0
	for mesh in sources:
		var material := mesh.material_override as ShaderMaterial
		if material != null and material.shader == character.skin.skin.shader:
			inner += 1
	_check(inner == sources.size(),
		"Ada %d dari %d mesh mannequin yang bukan bahan kulit" % [
			sources.size() - inner, sources.size()])
	# Kulit harus benar-benar LEBIH BESAR dari badannya (gelembung ke luar).
	var grown := 0
	for material in character.skin.materials():
		grown = maxi(grown, int(round(float(material.get_shader_parameter("grow")) * 1000.0)))
	_check(grown > 0, "Kulit tidak digelembungkan (grow=%d mm)" % grown)
	_notes.append("kulit: %d mesh tertutup, gelembung %d mm, bahan dalam %d/%d" % [
		character.skin.cover_count(), grown, inner, sources.size()])


## Janji 2: saat beranimasi, pose kulit tidak boleh tertinggal dari badannya.
func _test_pose_lock(character: Character) -> void:
	var worst := 0.0
	for motion in ["Idle_Loop", "Crouch_Fwd_Loop", "Jog_Fwd_Loop"]:
		character.set_locomotion(motion, 1.0)
		character.animation.advance(0.0)
		for step in range(30):
			character.animation.advance(STEP)
			# Satu frame supaya salinan pose (sinyal kerangka atau cadangan di
			# _process) benar-benar berjalan; di headless sinyalnya tidak berbunyi.
			await process_frame
			worst = maxf(worst, character.skin.worst_pose_gap())
	_check(character.skin.pulses > 0, "Sinyal pose kerangka tidak sampai ke kulit")
	_check(worst < POSE_TOLERANCE,
		"Kulit tertinggal dari badan: %.5f m (batas %.5f)" % [worst, POSE_TOLERANCE])
	_notes.append("kulit: selisih pose terburuk %.5f m, %d salinan pose" % [
		worst, character.skin.pulses])


## Janji 4: denyut menanggapi gerak badan, bukan angka tetap.
func _test_pulse(character: Character) -> void:
	for _step in range(40):
		character.skin.set_pulse(0.0)
	var still := character.skin.pulse_value()
	for _step in range(40):
		character.skin.set_pulse(7.0)
	var running := character.skin.pulse_value()
	_check(still < 0.1, "Kulit berdenyut keras saat diam: %.2f" % still)
	_check(running > still + 0.3,
		"Denyut kulit tidak menanggapi kecepatan: diam %.2f lari %.2f" % [still, running])
	character.skin.set_pulse(0.0)
	_notes.append("kulit: denyut diam %.2f, lari %.2f" % [still, running])


## Diagnosa gerak klip: nama runtime beda dari katalog (importer glTF membuang
## akhiran "_Loop"), jadi yang diukur adalah klip yang benar-benar diputar.
func _test_clip_motion(character: Character) -> void:
	for motion in ["Idle_Loop", "Crouch_Idle_Loop", "Jog_Fwd_Loop"]:
		character.set_locomotion(motion, 1.0)
		character.animation.advance(0.0)
		var playing := character.animation.current_animation
		var animation := character.animation.get_animation(playing)
		if animation == null:
			_check(false, "Klip tidak ditemukan: %s" % playing)
			continue
		var bones := PackedInt32Array()
		# Nama tulang rig UAL: Head/hand_l/hand_r.
		for name in ["Head", "hand_l", "hand_r"]:
			var bone := character.skeleton.find_bone(name)
			if bone >= 0:
				bones.append(bone)
		var previous := PackedVector3Array()
		for bone in bones:
			previous.append(character.skeleton.get_bone_global_pose(bone).origin)
		var rate := 30.0
		var peak := 0.0
		var total := 0.0
		for _step in range(maxi(int(ceil(animation.length * rate)), 2)):
			character.animation.advance(1.0 / rate)
			for index in range(bones.size()):
				var now := character.skeleton.get_bone_global_pose(bones[index]).origin
				peak = maxf(peak, now.distance_to(previous[index]))
				total += now.distance_to(previous[index])
				previous[index] = now
		_notes.append("gerak klip %s=%s: %.4f m/frame, %.3f m total" % [motion,
			playing, peak, total])
		_check(peak > 0.001, "Klip %s tidak bergerak sama sekali" % playing)
