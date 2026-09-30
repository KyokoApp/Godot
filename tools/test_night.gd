extends SceneTree

const Night = preload("res://src/game/environment/night_environment.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _capture() -> Image:
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _difference(first: Image, second: Image) -> int:
	var count := 0
	for y in range(first.get_height()):
		for x in range(first.get_width()):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() > 0.08:
				count += 1
	return count


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Night.make_environment()
	world.add_child(environment)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 65
	camera.look_at(Vector3(0, 0.48, -1))
	var material := environment.environment.sky.sky_material as ShaderMaterial
	var full: Image = await _capture()
	full.save_png("user://night-sky-test.png")
	material.set_shader_parameter("moon_enabled", false)
	var no_moon: Image = await _capture()
	var moon_area := _difference(full, no_moon)
	_check(moon_area >= 2 and moon_area < 250, "Bulan tidak terlihat atau terlalu besar")
	material.set_shader_parameter("stars_enabled", false)
	var plain: Image = await _capture()
	var stars_area := _difference(no_moon, plain)
	_check(stars_area > 2 and stars_area < 600, "Bintang tidak terlihat atau terlalu ramai")
	var zenith := plain.get_pixel(plain.get_width() / 2, 10)
	_check(zenith.b > zenith.r and zenith.b < 0.5, "Langit bukan biru malam")
	material.set_shader_parameter("moon_enabled", true)
	material.set_shader_parameter("stars_enabled", true)
	var light := Night.make_moonlight()
	world.add_child(light)
	light.look_at_from_position(Vector3.ZERO, -Night.MOON_DIRECTION)
	_check(light.global_basis.z.dot(Night.MOON_DIRECTION) > 0.999,
		"Arah pencahayaan tidak sesuai bulan")
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Color("59a541")
	grass.roughness = 1
	ground.material_override = grass
	world.add_child(ground)
	camera.position = Vector3(0, 4, 8)
	camera.look_at(Vector3.ZERO)
	var readable: Image = await _capture()
	var center := readable.get_pixel(readable.get_width() / 2, readable.get_height() / 2)
	_check(center.g > 0.04 and center.g > center.r, "Tanah hijau terlalu gelap untuk dibaca")
	readable.save_png("user://night-ground-test.png")
	print("[night-test] moon pixels=", moon_area, " stars pixels=", stars_area)
	print("[night-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
