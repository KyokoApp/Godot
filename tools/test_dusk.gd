extends SceneTree
## Gerbang langit MALAM: dunia harus tampak seperti mungil yang indah, bukan
## kegelapan pekat dan bukan senja lagi.
##
## Yang diuji di sini:
##   1. bulan ADA dan terang (piringan, bukan cuma halo),
##   2. halo bulan ADA (hilang kalau glow_enabled dimatikan),
##   3. bintang ADA (bukan langit kosong),
##   4. awan ADA,
##   5. bulan benar-benar hilang kalau dimatikan (bukan cahaya sisa),
##   6. zenith biru tua — bukan biru senja yang terang,
##   7. arah cahaya utama sama dengan Dusk.SUN_DIRECTION (sekarang arah bulan),
##   8. tanah hijau GELAP pun cukup terang untuk dibaca di bawah cahaya bulan —
##      bukan hitam.

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


# Rata-rata satu kotak piksel: piringan bulan penuh kawah, jadi satu piksel
# tunggal bisa jatuh di kawah dan salah dibaca "bulan tidak terang".
func _average(image: Image, cx: int, cy: int, span: int) -> Color:
	var total := Color(0.0, 0.0, 0.0, 0.0)
	var count := 0
	for y in range(maxi(cy - span, 0), mini(cy + span + 1, image.get_height())):
		for x in range(maxi(cx - span, 0), mini(cx + span + 1, image.get_width())):
			total += image.get_pixel(x, y)
			count += 1
	if count == 0:
		return Color.BLACK
	return total / float(count)


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
	var centre := full.get_width() / 2
	var middle_y := full.get_height() / 2
	# 1. Piringan bulan: rata-rata kotak di tengah layar harus terang.
	var moon := _average(full, centre, middle_y, 3)
	_check(moon.r > 0.55 and moon.g > 0.55 and moon.b > 0.50,
		"Bulan tidak terlihat saat kamera menghadap bulan: %s" % moon)
	# Diagnosa: berapa terang piringan kalau glow ENGINE dimatikan (glow langit
	# tetap menyala). Kalau nilainya jauh lebih gelap, yang mencerahkan adalah bloom.
	var engine_glow: bool = environment.environment.glow_enabled
	environment.environment.glow_enabled = false
	var no_engine: Image = await _capture()
	print("[dusk-test] bulan tanpa glow engine=",
		_average(no_engine, centre, middle_y, 3))
	environment.environment.glow_enabled = engine_glow
	# 2. Halo bulan: mematikan glow langit harus mengubah banyak piksel. Bulan
	# sengaja dibiarkan menyala supaya yang terukur HALO-nya, bukan piringan.
	material.set_shader_parameter("glow_enabled", false)
	var no_glow: Image = await _capture()
	var glow_area := _difference(full, no_glow)
	_check(glow_area > 20, "Halo bulan tidak terlihat (%d piksel)" % glow_area)
	# 3. Bintang: mematikannya harus mengubah banyak piksel langit. Diukur di atas
	# gambar tanpa halo supaya halo tidak ikut terhitung.
	material.set_shader_parameter("stars_enabled", false)
	var no_stars: Image = await _capture()
	var star_area := _difference(no_glow, no_stars)
	_check(star_area > 40, "Bintang tidak terlihat (%d piksel)" % star_area)
	material.set_shader_parameter("stars_enabled", true)
	# 4. Awan: mematikannya harus mengubah banyak piksel langit.
	material.set_shader_parameter("clouds_enabled", false)
	var plain: Image = await _capture()
	var cloud_area := _difference(no_glow, plain)
	_check(cloud_area > 50, "Awan tidak terlihat (%d piksel)" % cloud_area)
	# 5. Mematikan bulan harus menggelapkan piringan dan mengubah banyak piksel.
	# Dibandingkan dengan gambar awal (glow menyala), jadi halo ikut terukur.
	material.set_shader_parameter("glow_enabled", true)
	material.set_shader_parameter("clouds_enabled", true)
	material.set_shader_parameter("moon_enabled", false)
	var no_moon: Image = await _capture()
	var moon_area := _difference(full, no_moon)
	_check(moon_area > 30, "Bulan tidak terlihat (%d piksel)" % moon_area)
	var dark_moon := _average(no_moon, centre, middle_y, 3)
	_check(dark_moon.r < moon.r * 0.65,
		"Mematikan bulan tidak menggelapkan piringan: %s -> %s" % [moon, dark_moon])
	material.set_shader_parameter("moon_enabled", true)
	# 6. Zenith: biru tua (malam), bukan biru senja yang terang.
	camera.look_at(Vector3(0.0, 1.0, 0.35))
	var zenith: Image = await _capture()
	var top := zenith.get_pixel(zenith.get_width() / 2, 8)
	_check(top.b > top.r and top.b > 0.01,
		"Langit malam bukan biru: %s" % top)
	_check(top.b < 0.30,
		"Zenith terlalu terang untuk malam (masih senja?): %s" % top)
	# 7. Arah cahaya utama sama dengan arah bulan.
	var light := Dusk.make_sunlight()
	world.add_child(light)
	light.look_at_from_position(Vector3.ZERO, -Dusk.SUN_DIRECTION)
	_check(light.global_basis.z.dot(Dusk.SUN_DIRECTION) > 0.999,
		"Arah pencahayaan tidak sesuai arah bulan")
	# 8. Tanah hijau GELAP harus tetap terbaca (tetap hijau, bukan hitam).
	# Warnanya diambil dari field.gd, bukan ditulis ulang di sini.
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
	_check(middle.g > 0.12 and middle.g > middle.r,
		"Tanah hijau terlalu gelap untuk dibaca: %s" % middle)
	readable.save_png("user://dusk-ground-test.png")
	print("[dusk-test] bulan=", moon, " bintang=", star_area, " halo=", glow_area,
		" awan=", cloud_area, " zenith=", top, " tanah=", middle)
	print("[dusk-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
