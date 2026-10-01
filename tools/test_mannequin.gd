extends SceneTree
## Mannequin satu-satunya karakter: SEMUA klip katalog harus ada, mode loop benar,
## metrik langkah terukur, aksi sekali jalan kembali sendiri, lapisan casting aman.

const Character = preload("res://src/game/mannequin.gd")
const Catalog = preload("res://src/game/animation/catalog.gd")
const Metrics = preload("res://src/game/animation/anim_metrics.gd")
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
	var animation := character.animation
	var skeleton := character.skeleton
	_check(animation != null and skeleton != null, "Rig/AnimationPlayer hilang")
	if animation == null or skeleton == null:
		quit(1)
		return
	_check(character.get("skin_id") == null, "API skin lama masih ada")
	for node in character.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var material := mesh.material_override as StandardMaterial3D
		_check(material != null and material.next_pass is ShaderMaterial,
			"Outline mannequin hilang")
	_test_catalog(character, animation, skeleton)
	_test_metrics(character)
	_test_state_machine(character)
	_test_cast(character, skeleton)
	_test_feet(character)
	print("[mannequin-test] klip=%d metrik=%d gagal=%d" % [
		animation.get_animation_list().size(), character.metrics.size(), _failures])
	quit(0 if _failures == 0 else 1)


func _test_catalog(character: Character, animation: AnimationPlayer,
		skeleton: Skeleton3D) -> void:
	var entries := Catalog.entries()
	_check(entries.size() == Catalog.clip_count(), "Katalog tidak konsisten")
	_check(entries.size() == 85, "Jumlah klip katalog bukan 85: %d" % entries.size())
	var missing: Array[String] = []
	for entry in entries:
		var name: String = entry["name"]
		var play_name: String = Catalog.play_name(name)
		if not animation.has_animation(play_name):
			missing.append(name)
			continue
		var clip := animation.get_animation(play_name)
		var expected := Animation.LOOP_LINEAR if Catalog.is_loop(name) else Animation.LOOP_NONE
		_check(clip.loop_mode == expected, "Mode loop salah: " + name)
		_check(clip.length > 0.05, "Durasi klip terlalu pendek: " + name)
		for track in range(clip.get_track_count()):
			var path := clip.track_get_path(track)
			if path.get_subname_count() != 1:
				continue
			var bone := path.get_subname(0)
			if bone != "" and skeleton.find_bone(bone) < 0 and bone != skeleton.name:
				_check(false, "Tulang tidak dikenal di %s: %s" % [name, bone])
	_check(missing.is_empty(), "Klip katalog hilang: " + ", ".join(missing))
	# Nama mentah kedua berkas harus benar-benar terpakai.
	_check(animation.has_animation("ual2/Sword_Regular_Combo"), "Pustaka UAL2 tidak tergabung")
	_check(animation.has_animation(Catalog.play_name("Walk_Loop"))
		and animation.has_animation(Catalog.play_name("Zombie_Scratch")),
		"Gabungan pustaka UAL1+UAL2 tidak lengkap")
	_check(character.description_of("Roll").length() > 10, "Keterangan klip kosong")
	_check(character.length_of("Walk_Loop") > 1.2 and character.length_of("Walk_Loop") < 1.5,
		"Durasi Walk_Loop tidak sesuai berkas")


func _test_metrics(character: Character) -> void:
	_check(character.metrics.size() == Catalog.clip_count(),
		"Metrik tidak terukur untuk semua klip")
	var expected := {
		"Walk_Loop": Vector2(0.7, 1.6),
		"Jog_Fwd_Loop": Vector2(2.0, 3.6),
		"Sprint_Loop": Vector2(2.4, 4.6),
		"Crouch_Fwd_Loop": Vector2(0.4, 1.2),
		"Walk_Carry_Loop": Vector2(0.4, 1.2),
		"Zombie_Walk_Fwd_Loop": Vector2(0.6, 1.6),
		"Swim_Fwd_Loop": Vector2(0.02, 2.0),
	}
	for clip: String in expected:
		var speed := character.natural_speed(clip)
		var band: Vector2 = expected[clip]
		_check(speed >= band.x and speed <= band.y,
			"Kecepatan alami %s di luar dugaan: %.2f m/s" % [clip, speed])
	# Offset tanah: klip rendah butuh koreksi naik, klip berdiri tidak.
	var idle_offset := float(character.metrics["Idle_Loop"]["ground_offset"])
	_check(idle_offset == 0.0, "Pose berdiri justru digeser: %.3f" % idle_offset)
	for clip in ["Roll", "Slide_Start", "Slide_Exit", "Death01"]:
		var offset := float(character.metrics[clip]["ground_offset"])
		_check(offset >= 0.0 and offset <= Metrics.MAX_OFFSET,
			"Offset tanah %s tidak wajar: %.3f" % [clip, offset])
	_check(character.metrics["Death01"]["length"] > 2.0, "Durasi Death01 salah")
	_check(character.metrics["Sword_Heavy_Combo"]["length"] > 4.0,
		"Durasi Sword_Heavy_Combo salah")


func _test_state_machine(character: Character) -> void:
	character.set_locomotion("Walk_Loop", 1.0)
	_check(character.clip == "Walk_Loop" and not character.is_busy(),
		"Lokomosi tidak memutar Walk_Loop")
	character.set_locomotion("Jog_Fwd_Loop", 1.2)
	_check(character.clip == "Jog_Fwd_Loop", "Ganti klip lokomosi gagal")
	_check(is_equal_approx(character.animation.speed_scale, 1.2),
		"Skala kecepatan lokomosi tidak diterapkan")
	var length := character.play_action("Punch_Jab")
	_check(length > 0.5 and character.is_busy(), "Aksi sekali jalan tidak dimulai")
	character.set_locomotion("Sprint_Loop", 1.0)
	_check(character.clip == "Punch_Jab", "Aksi ditimpa lokomosi")
	character._physics_process(length + 0.05)
	_check(not character.is_busy() and character.clip == "Sprint_Loop",
		"Aksi tidak kembali ke gait terakhir yang diminta")
	character.play_showcase("Dance_Loop")
	_check(character.mode == Character.Mode.SHOWCASE, "Klip loop panel tidak masuk mode showcase")
	character._physics_process(2.0)
	_check(character.clip == "Dance_Loop", "Klip showcase loop berhenti sendiri")
	character.play_showcase("Death01")
	_check(character.mode == Character.Mode.ACTION, "Klip sekali panel tidak masuk mode aksi")
	character._physics_process(5.0)
	_check(character.mode == Character.Mode.HELD, "Death01 tidak berhenti di frame akhir")
	_check(character.animation.is_playing() == false, "Frame akhir tidak dibekukan")
	character.return_to_locomotion()
	_check(character.mode == Character.Mode.LOCOMOTION and character.animation.is_playing(),
		"Kembali ke lokomosi dari pose beku gagal")
	# Skala lambat hanya untuk klip tampilan, bukan lokomosi badan.
	character.set_playback_scale(0.5)
	character.play_showcase("Walk_Loop")
	_check(is_equal_approx(character.animation.speed_scale, 0.5),
		"Mode lambat tidak diterapkan pada klip tampilan")
	character.return_to_locomotion()
	character.set_playback_scale(1.0)


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
	for motion in ["Idle_Loop", "Walk_Loop", "Jog_Fwd_Loop"]:
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
		_check(character.animation.current_animation == motion,
			"Casting mengganti clock langkah")
		layer._physics_process(0.4)
		_check(not layer.playing and not layer.active and layer.influence == 0,
			"Casting tidak kembali ke locomotion")
		character.animation.advance(0)
	character.play_action("Spell_Simple_Shoot")
	character.start_cast()
	_check(layer.playing, "Casting tidak jalan saat aksi sihir")
	character._physics_process(1.0)
	_check(not character.is_busy(), "Aksi sihir tidak selesai")


func _test_feet(character: Character) -> void:
	character.set_locomotion("Jog_Fwd_Loop", 1.0)
	character.animation.advance(0.3)
	for left in [true, false]:
		var pose := character.foot_pose(left)
		_check(pose.origin.is_finite() and pose.basis.is_finite(), "Foot binding tidak valid")
		_check(character.foot_clearance(left) > 0.05, "Sole clearance tidak valid")
	_check(absf(character.ground_offset) < 0.3, "Offset tanah keluar batas")
