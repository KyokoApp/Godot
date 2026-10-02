extends SceneTree
## Gerbang contact shadow: sinar ditembakkan dari setiap piksel ke arah matahari,
## jadi bayangan HARUS jatuh di sisi berlawanan dari matahari. Kalau arahnya
## terbalik — NDC Y yang salah flip, atau reverse-Z yang terbaca terbalik —
## bayangan justru muncul di DEPAN balok. Itu yang ditangkap tes ini lewat
## perbandingan A/B (efek nyala vs mati), seperti test_sun_rays.gd.
const ContactShadows = preload("res://src/game/god_rays/contact_shadows.gd")
const Dusk = preload("res://src/game/environment/dusk_environment.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Dusk.make_environment()
	world.add_child(env)
	# Bayangan peta DIMATIKAN: yang boleh menggelapkan sisi belakang balok hanya
	# contact shadow, jadi perbandingan A/B benar-benar menguji lapisan ini.
	var sun := Dusk.make_sunlight()
	sun.shadow_enabled = false
	world.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, -Dusk.SUN_DIRECTION)
	var camera := Camera3D.new()
	# Kamera cukup tinggi supaya sinar kontak jelas melayang di atas tanah datar
	# (kalau terlalu rendah, tanah sendiri bisa terbaca sebagai penghalang).
	camera.position = Vector3(0.0, 6.0, 18.0)
	world.add_child(camera)
	camera.current = true
	camera.look_at(Vector3(0.0, 1.0, 0.0))
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200.0, 200.0)
	ground.mesh = plane
	world.add_child(ground)
	# Balok 5 m: cukup tinggi untuk kontak 21 m, cukup sempit supaya titik
	# terang dan titik gelapnya terpisah jelas di layar.
	var block := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 5.0, 2.0)
	block.mesh = box
	block.position = Vector3(0.0, 2.5, 0.0)
	world.add_child(block)
	var contact := ContactShadows.new()
	contact.camera = camera
	camera.add_child(contact)
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var on: Image = root.get_texture().get_image()
	contact.enabled = false
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var off: Image = root.get_texture().get_image()
	on.save_png("user://contact-shadow-on.png")
	off.save_png("user://contact-shadow-off.png")
	# Matahari di barat (-x): bayangan harus jatuh ke +x (belakang balok),
	# sisi -x (menghadap matahari) harus tetap terang.
	var shadow_point := camera.unproject_position(Vector3(2.0, 0.05, 0.0))
	var lit_point := camera.unproject_position(Vector3(-4.0, 0.05, 0.0))
	var shadow_darkening: float = _darkening(off, on, shadow_point)
	var lit_darkening: float = _darkening(off, on, lit_point)
	print("[contact-test] gelap di belakang balok=", shadow_darkening,
		" di depan balok=", lit_darkening)
	_check(shadow_darkening > 0.02,
		"Contact shadow tidak muncul di belakang balok: %f" % shadow_darkening)
	_check(lit_darkening < 0.01,
		"Contact shadow bocor ke sisi yang menghadap matahari: %f" % lit_darkening)
	_check(shadow_darkening > lit_darkening * 3.0,
		"Arah contact shadow tidak meyakinkan: belakang %f vs depan %f"
		% [shadow_darkening, lit_darkening])
	# Sakelar grafis harus benar-benar mematikan lapisan ini.
	contact.enabled = false
	await process_frame
	_check(not contact.visible, "Contact shadow masih terlihat setelah dimatikan")
	contact.enabled = true
	await process_frame
	_check(contact.visible, "Contact shadow tidak menyala setelah diaktifkan")
	world.queue_free()
	await process_frame
	print("[contact-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)


## Seberapa besar sebuah titik menggelap saat efek NYALA dibanding MATI.
## Rata-rata patch 7x7 supaya satu piksel noise renderer software tidak
## menentukan hasil.
func _darkening(off: Image, on: Image, point: Vector2) -> float:
	var total := 0.0
	var count := 0
	for y in range(int(point.y) - 3, int(point.y) + 4):
		for x in range(int(point.x) - 3, int(point.x) + 4):
			if x < 0 or y < 0 or x >= on.get_width() or y >= on.get_height():
				continue
			total += off.get_pixel(x, y).get_luminance() - on.get_pixel(x, y).get_luminance()
			count += 1
	return total / maxf(float(count), 1.0)
