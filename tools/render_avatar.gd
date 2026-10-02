extends SceneTree
## Render avatar Aurelia dari kamera pemain pada beberapa jarak, lalu simpan
## sebagai PNG untuk diperiksa mata (dan dikirim sebagai pratinjau di CI).
##
## Kenapa ada tes ini: bug material (rambut memakai atlas jubah, mata memakai
## atlas rambut, sisi dalam mesh ikut tergambar) TIDAK bisa ditangkap oleh
## pemeriksaan angka — hanya terlihat dari gambar. Jarak 0,4 m = zoom terdekat
## yang sekarang mungkin dipakai pemain, jadi itu yang dirender lebih dulu.

const Catalog = preload("res://src/game/animation/catalog.gd")
const Orbit = preload("res://src/game/orbit_camera.gd")
const Humanoid = preload("res://src/game/animation/humanoid_map.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
	print("::error::", message)


func _run() -> void:
	var game: Node3D = load("res://src/game/main.tscn").instantiate()
	root.add_child(game)
	for frame in range(90):
		await physics_frame
		if (game.get("_player") as CharacterBody3D).is_on_floor():
			break
	var orbit: Orbit = game.get("_orbit")
	_check(orbit != null, "Kamera orbit tidak ditemukan")
	if orbit == null:
		quit(1)
		return
	orbit.exclusions = []
	# Sorot wajah: sudut sedikit dari depan supaya mata dan rambut depan terlihat.
	orbit.yaw = PI
	orbit.pitch = 0.18
	var views := [
		{"distance": 0.40, "name": "dekat"},
		{"distance": 0.85, "name": "kepala"},
		{"distance": 2.20, "name": "badan"},
	]
	for view: Dictionary in views:
		orbit.distance = float(view["distance"])
		await _capture("avatar-%s" % view["name"])
	# Pose jalan: kaki mengayun, jadi kain/rok ikut bergerak dan bisa diperiksa
	# apakah ada panel yang menembus badan.
	(game.get("_visual") as Node).set_locomotion("Walk_Loop", 1.0)
	for frame in range(24):
		await physics_frame
	await _capture("avatar-jalan")
	(game.get("_visual") as Node).set_locomotion("Jog_Fwd_Loop", 1.0)
	for frame in range(30):
		await physics_frame
	await _capture("avatar-lari")
	print("[avatar-render-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	game.queue_free()
	for frame in range(4):
		await process_frame
	quit(0 if _failures == 0 else 1)


func _capture(name: String) -> void:
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "user://%s-test.png" % name
	image.save_png(path)
	print("[avatar-render-test] ", path, " ", image.get_width(), "x", image.get_height())
