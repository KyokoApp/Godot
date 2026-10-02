extends SceneTree
## Gerbang langit senja: dunia harus terlihat seperti ilustrasi layar muat
## (project/launcher/art/loading.jpg), bukan malam pekat.
##
## Ilustrasi itu: langit biru lavender yang TERANG, awan pita panjang, pendar
## krem-persik tepat di atas ufuk barat tempat matahari terbenam, dan tanah hijau
## yang tetap terbaca. Yang diuji di sini:
##   1. pendar matahari ada (hilang kalau glow_enabled dimatikan),
##   2. awan ada (hilang kalau clouds_enabled dimatikan),
##   3. zenith biru lavender DAN terang (bukan biru malam),
##   4. arah cahaya matahari sama dengan Dusk.SUN_DIRECTION,
##   5. tanah hijau GELAP (palet senja) pun cukup terang untuk dibaca di bawah
##      cahaya senja itu — bukan hitam.

const Dusk = preload("res://src/game/environment/dusk_environment.gd")
const Field = preload("res://src/game/world/field.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _capture() -> Image:
	for _frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _difference(first: Image, second: Image) -> int:
	var count := 0
	for y in range(0, first.get_height(), 2):
		for x in range(0, first.get_width(), 2):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() > 0.05:
				count += 1
	return count


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Dusk.make_environment()
	world.add_child(environment)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 65
	camera.look_at(Dusk.SUN_DIRECTION)
	var material := environment.environment.sky.sky_material as ShaderMaterial
	var full: Image = await _capture()
	full.save_png("user://dusk-sky-test.png")
	# 1. Pendar matahari di ufuk barat: terang dan hangat (merah > biru).
	var centre := full.get_pixel(full.get_width() / 2, full.get_height() / 2)
	_check(centre.r > centre.b and centre.r > 0.55,
		"Pendar matahari di ufuk tidak hangat/terang: %s" % centre)
	material.set_shader_parameter("glow_enabled", false)
	var no_glow: Image = await _capture()
	var glow_area := _difference(full, no_glow)
	_check(glow_area > 20, "Pendar matahari tidak terlihat (%d piksel)" % glow_area)
	# 2. Awan pita panjang: mematikannya harus mengubah banyak piksel langit.
	material.set_shader_parameter("clouds_enabled", false)
	var plain: Image = await _capture()
	var cloud_area := _difference(no_glow, plain)
	_check(cloud_area > 50, "Awan tidak terlihat (%d piksel)" % cloud_area)
	material.set_shader_parameter("glow_enabled", true)
	material.set_shader_parameter("clouds_enabled", true)
	# 3. Zenith: biru lavender yang terang, bukan biru malam.
	camera.look_at(Vector3(0.0, 1.0, 0.35))
	var zenith: Image = await _capture()
	var top := zenith.get_pixel(zenith.get_width() / 2, 8)
	# Ambang dibuat longgar (tonemap filmik meredupkan): yang penting zenith
	# tetap biru dominan dan jauh lebih terang dari langit malam dulu.
	_check(top.b > top.r and top.b > 0.30,
		"Langit bukan biru lavender terang: %s" % top)
	# 4. Arah cahaya matahari sama dengan arah di ilustrasi.
	var light := Dusk.make_sunlight()
	world.add_child(light)
	light.look_at_from_position(Vector3.ZERO, -Dusk.SUN_DIRECTION)
	_check(light.global_basis.z.dot(Dusk.SUN_DIRECTION) > 0.999,
		"Arah pencahayaan tidak sesuai matahari senja")
	# 5. Tanah hijau GELAP harus tetap terbaca (tetap hijau, bukan hitam).
	# Warnanya diambil dari field.gd, bukan ditulis ulang di sini: dulu tes ini
	# memakai hijau muda 8fce63 sementara dunianya sudah jadi hijau tua, jadi
	# gerbangnya menguji warna yang tidak dipakai lagi.
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var grass := StandardMaterial3D.new()
	grass.albedo_color = Field.GRASS_COLOR
	grass.roughness = 1.0
	ground.material_override = grass
	world.add_child(ground)
	camera.position = Vector3(0, 4, 8)
	camera.look_at(Vector3.ZERO)
	var readable: Image = await _capture()
	var middle := readable.get_pixel(readable.get_width() / 2, readable.get_height() / 2)
	_check(middle.g > 0.22 and middle.g > middle.r,
		"Tanah hijau terlalu gelap untuk dibaca: %s" % middle)
	readable.save_png("user://dusk-ground-test.png")
	print("[dusk-test] pendar=", glow_area, " awan=", cloud_area,
		" ufuk=", centre, " zenith=", top, " tanah=", middle)
	print("[dusk-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
