extends SceneTree
## Exercise native post-animation modifier + skinning, not just manually sampled bones.

const Character = preload("res://src/game/mannequin.gd")
const Night = preload("res://src/game/environment/night_environment.gd")
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
	var environment := WorldEnvironment.new()
	environment.environment = Night.make_environment()
	world.add_child(environment)
	var light := Night.make_moonlight()
	world.add_child(light)
	light.look_at_from_position(Vector3.ZERO, -Night.MOON_DIRECTION)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(2.3, 1.7, 3.2)
	camera.look_at(Vector3(0, 1, 0))
	camera.current = true
	var character := Character.new()
	world.add_child(character)
	character.animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	character.cast_layer.set_physics_process(false)
	character.cast_layer.modification_processed.connect(func() -> void: _processed += 1)
	for skin in [Character.MANNEQUIN, Character.MIKU, Character.KANNA]:
		_check(character.set_skin(skin), "Skin gagal dimuat: " + skin)
		if character.hair != null:
			character.hair.active = false # isolate casting restoration from secondary motion
		await _test_skin(character, skin)
	_check(_processed > 0, "Native skeleton modifier tidak pernah diproses")
	world.queue_free()
	for frame in range(5):
		await process_frame
	print("[cast-render-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)


func _test_skin(character: Character, skin: String) -> void:
	for motion in [Character.IDLE, Character.RUN]:
		character.animation.play(motion, 0)
		character.animation.advance(0.2)
		var before: Image = await _capture(character)
		character.start_cast()
		character.cast_layer._physics_process(0.20)
		var cast: Image = await _capture(character)
		var changed := _difference(before, cast)
		_check(changed > 30, "Casting tidak terlihat pada skin: " + motion)
		cast.save_png("user://casting-" + skin + "-" + motion + "-test.png")
		character.cast_layer._physics_process(0.4)
		var after: Image = await _capture(character)
		_check(_difference(before, after) < 15, "Pose tidak pulih setelah casting: " + motion)
		print("[cast-render-test] ", motion, " changed pixels=", changed)
