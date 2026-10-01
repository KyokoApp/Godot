extends SceneTree
## Render Mobile: tapak api 3D harus terlihat, punya volume dari samping,
## dan stamp baru selalu menghasilkan gambar (bukti pipeline material hidup).

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
			if Vector3(first.r - second.r, first.g - second.g,
					first.b - second.b).length() > 0.06:
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
	camera.position = Vector3(0, 1.4, 2)
	camera.look_at(Vector3(0, 0.2, 0))
	var trail := Trail.new()
	world.add_child(trail)
	trail.set_physics_process(false)
	var empty: Image = await _capture()
	trail.add_stamp(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 4), Vector3.ZERO))
	var front: Image = await _capture()
	var changed := _difference(empty, front)
	_check(changed > 60, "Jejak 3D tidak dirender")
	front.save_png("user://motion-foot-test.png")
	camera.position = Vector3(2, 1.0, 0)
	camera.look_at(Vector3(0, 0.2, 0))
	var side: Image = await _capture()
	side.save_png("user://motion-foot-side-test.png")
	_check(_difference(side, empty) > 40, "Api tidak memiliki volume dari samping")
	trail.clear()
	var cleared: Image = await _capture()
	_check(_difference(cleared, empty) < 30, "Stamp tidak hilang setelah clear")
	world.queue_free()
	for frame in range(5):
		await process_frame
	print("[motion-flair-render-test] changed=", changed)
	print("[motion-flair-render-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
