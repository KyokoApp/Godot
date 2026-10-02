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
	# Sembunyikan efek yang menghalangi pandangan (pet api, aura kecepatan, tapak
	# api, sinar bulan): yang diperiksa di sini avatar-nya, bukan efeknya.
	for node_name in ["_pet", "_speed_aura", "_foot_fire", "_moon_rays", "_banner"]:
		var effect: Node = game.get(node_name)
		if effect is Node3D:
			(effect as Node3D).visible = false
		if effect != null:
			effect.set_process(false)
	# Sudut & jarak: depan untuk wajah, samping untuk kain, belakang untuk
	# rambut belakang dan rok (di situlah tembus badan paling terlihat).
	var views := [
		{"distance": 0.40, "name": "dekat", "yaw": PI, "pitch": 0.18},
		{"distance": 0.85, "name": "kepala", "yaw": PI, "pitch": 0.18},
		{"distance": 2.20, "name": "badan", "yaw": PI, "pitch": 0.26},
		{"distance": 2.20, "name": "samping", "yaw": PI * 0.5, "pitch": 0.20},
		{"distance": 2.20, "name": "belakang", "yaw": 0.0, "pitch": 0.20},
	]
	for view: Dictionary in views:
		orbit.distance = float(view["distance"])
		orbit.yaw = float(view["yaw"])
		orbit.pitch = float(view["pitch"])
		await _capture("avatar-%s" % view["name"])
	# Pose rendah (jongkok): rok paling mungkin menembus paha di pose ini.
	(game.get("_visual") as Node).set_locomotion("Crouch_Fwd_Loop", 1.0)
	orbit.yaw = PI * 0.5
	for frame in range(30):
		await physics_frame
	await _capture("avatar-jongkok")
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
