extends SceneTree
## Exercise native post-animation modifier + skinning, not just manually sampled bones.

const Catalog = preload("res://src/game/animation/catalog.gd")
const Character = preload("res://src/game/mannequin.gd")
const Dusk = preload("res://src/game/environment/dusk_environment.gd")
var _failures := 0
var _processed := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _capture(character: Character) -> Image:
	for frame in range(4):
		character.animation.advance(0)
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


## Posisi tulang seluruh badan (3 angka per tulang), dipakai untuk menilai
## pemulihan pose dari ANGKANYA, bukan dari piksel: bahan kulit berdenyut
## mengikuti TIME, jadi gambarnya berubah sendiri walau badannya diam.
func _pose_snapshot(character: Character) -> PackedFloat32Array:
	var skeleton := character.skeleton
	var data := PackedFloat32Array()
	data.resize(skeleton.get_bone_count() * 3)
	for bone in range(skeleton.get_bone_count()):
		var position := skeleton.get_bone_pose_position(bone)
		data[bone * 3] = position.x
		data[bone * 3 + 1] = position.y
		data[bone * 3 + 2] = position.z
	return data


## Selisih tulang terburuk terhadap pose acuan (meter).
func _pose_gap(rest: PackedFloat32Array, character: Character) -> float:
	var skeleton := character.skeleton
	var worst := 0.0
	for bone in range(skeleton.get_bone_count()):
		var wanted := Vector3(rest[bone * 3], rest[bone * 3 + 1], rest[bone * 3 + 2])
		worst = maxf(worst, wanted.distance_to(skeleton.get_bone_pose_position(bone)))
	return worst


func _difference(first: Image, second: Image) -> int:
	var changed := 0
	for y in range(first.get_height()):
		for x in range(first.get_width()):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() > 0.06:
				changed += 1
	return changed


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	# Latar polos, bukan langit senja: awan bergerak mengikuti TIME, dan gerakan
	# latar itu ikut terhitung sebagai "piksel berubah" sehingga uji pemulihan
	# pose jadi rapuh (pernah gagal padahal posenya benar).
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.10, 0.12, 0.18)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.62, 0.68, 0.86)
	environment.environment.ambient_light_energy = 0.58
	world.add_child(environment)
	var light := Dusk.make_sunlight()
	world.add_child(light)
	light.look_at_from_position(Vector3.ZERO, -Dusk.SUN_DIRECTION)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(2.3, 1.7, 3.2)
	camera.look_at(Vector3(0, 1, 0))
	camera.current = true
	var character := Character.new()
	world.add_child(character)
	character.animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	character.cast_layer.set_physics_process(false)
	# Nama sinyal engine bisa berbeda antar rilis 4.x: pakai connect berbasis nama,
	# hitungannya hanya info. Bukti utama tetap selisih piksel di bawah.
	if character.cast_layer.has_signal("modification_processed"):
		character.cast_layer.connect("modification_processed",
			func() -> void: _processed += 1)
	await _test_clip(character)
	print("[cast-render-test] modifier processed=", _processed)
	world.queue_free()
	for frame in range(5):
		await process_frame
	print("[cast-render-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)


func _test_clip(character: Character) -> void:
	for motion in ["Idle_Loop", "Jog_Fwd_Loop"]:
		character.animation.play(Catalog.play_name(motion), 0)
		character.animation.advance(0.2)
		var before: Image = await _capture(character)
		var rest := _pose_snapshot(character)
		character.start_cast()
		character.cast_layer._physics_process(0.20)
		var cast: Image = await _capture(character)
		var changed := _difference(before, cast)
		_check(changed > 30, "Casting tidak terlihat pada klip: " + motion)
		cast.save_png("user://casting-" + motion + "-test.png")
		character.cast_layer._physics_process(0.4)
		var after: Image = await _capture(character)
		var gap := _pose_gap(rest, character)
		_check(gap < 0.001, "Pose tidak pulih setelah casting: %s (selisih %.4f m)"
			% [motion, gap])
		print("[cast-render-test] ", motion, " changed pixels=", changed,
			" selisih pose pulih=%.5f m" % gap)
