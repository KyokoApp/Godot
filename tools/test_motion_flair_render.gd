extends SceneTree

const Character = preload("res://src/game/mannequin.gd")
const Trail = preload("res://src/game/foot_fire/foot_fire_trail.gd")
const Night = preload("res://src/game/environment/night_environment.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _difference(a: Image, b: Image) -> int:
	var count := 0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			var first := a.get_pixel(x, y)
			var second := b.get_pixel(x, y)
			if Vector3(first.r - second.r, first.g - second.g, first.b - second.b).length() > 0.06:
				count += 1
	return count


func _capture() -> Image:
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _run() -> void:
	Engine.max_fps = 60
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
	camera.current = true
	await _test_hair(world, camera)
	camera.position = Vector3(0, 1.4, 2)
	camera.look_at(Vector3(0, 0.2, 0))
	var trail := Trail.new()
	world.add_child(trail)
	trail.set_physics_process(false)
	var empty: Image = await _capture()
	var previous := empty
	for skin in ["miku", "kanna", "mannequin"]:
		trail.clear()
		trail.add_stamp(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 4), Vector3.ZERO), skin)
		var image: Image = await _capture()
		_check(_difference(empty, image) > 60, "Jejak 3D tidak dirender: " + skin)
		_check(_difference(previous, image) > 40, "Palet karakter tidak berbeda: " + skin)
		image.save_png("user://motion-foot-" + skin + "-test.png")
		previous = image
	camera.position = Vector3(2, 1.0, 0)
	camera.look_at(Vector3(0, 0.2, 0))
	var side: Image = await _capture()
	side.save_png("user://motion-foot-side-test.png")
	trail.clear()
	var no_side: Image = await _capture()
	_check(_difference(side, no_side) > 40, "Api tidak memiliki volume dari samping")
	world.queue_free()
	for frame in range(5):
		await process_frame
	print("[motion-flair-render-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)


func _test_hair(world: Node3D, camera: Camera3D) -> void:
	var character := Character.new()
	world.add_child(character)
	character.set_skin(Character.MIKU)
	character.animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	character.animation.advance(0.2)
	character.hair.active = false
	var fixed: Image = await _hair_capture(character, camera)
	character.hair.active = true
	character.hair.reset_motion()
	var moving: Image = await _hair_capture(character, camera)
	var changed := _difference(fixed, moving)
	_check(changed > 20, "Spring rambut tidak terlihat pada mesh berskin")
	moving.save_png("user://motion-hair-test.png")
	print("[motion-flair-render-test] hair changed pixels=", changed)
	character.queue_free()
	for frame in range(4):
		await process_frame


func _hair_capture(character: Character, camera: Camera3D) -> Image:
	for frame in range(45):
		character.position.x += 0.045
		camera.position = character.position + Vector3(0.8, 1.3, 3.1)
		camera.look_at(character.position + Vector3(0, 0.95, 0))
		character.animation.advance(0)
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
