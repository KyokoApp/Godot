extends SceneTree
## Render terisolasi: shader proyektil DAN impact harus terlihat, bukan hanya compile.

const Projectile = preload("res://src/game/fire_projectile.gd")
const Burst = preload("res://src/game/fire_burst.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _capture() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _changed(a: Image, b: Image) -> int:
	var count := 0
	for y in range(a.get_height()):
		for x in range(a.get_width()):
			var first := a.get_pixel(x, y)
			var second := b.get_pixel(x, y)
			if Vector3(first.r - second.r, first.g - second.g, first.b - second.b).length() > 0.1:
				count += 1
	return count


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.035, 0.055, 0.05)
	environment.environment = settings
	world.add_child(environment)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.8, 6)
	world.add_child(camera)
	camera.look_at(Vector3(0, 0.6, 0))
	camera.current = true
	var background: Image = await _capture()
	var shot := Projectile.new()
	shot.position = Vector3(0, 0.6, 0)
	world.add_child(shot)
	shot.set_physics_process(false)
	shot.velocity = Vector3(16, 0, 0)
	shot._process(0.1)
	var projectile: Image = await _capture()
	_check(_changed(background, projectile) > 15, "Api dan ekor proyektil tidak terlihat")
	projectile.save_png("user://fire-projectile-test.png")
	shot.queue_free()
	await process_frame
	var burst := Burst.new()
	world.add_child(burst)
	burst.set_process(false)
	burst.age = 0.22
	burst._update_visuals()
	var peak: Image = await _capture()
	var area := _changed(background, peak)
	_check(area > 500, "Ledakan tidak membentuk volume api besar")
	_check(area < background.get_width() * background.get_height() / 2,
		"Ledakan menutupi lebih dari separuh layar tes")
	peak.save_png("user://fire-impact-test.png")
	burst.age = 0.72
	burst._update_visuals()
	var late: Image = await _capture()
	_check(_changed(peak, late) > 100, "Ledakan tidak berubah saat meluruh")
	burst.age = Burst.LIFETIME
	burst._process(0.01)
	var cleared: Image = await _capture()
	_check(_changed(background, cleared) == 0, "Visual impact masih tertinggal setelah cleanup")
	print("[fire-render-test] area peak: ", area)
	print("[fire-render-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
