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
	# "leher": kamera setinggi leher dan sedikit dari bawah, karena leher hanya
	# terlihat jelas dari arah itu. "kain": jarak sedang dari samping, untuk
	# menilai kain yang kaku/menembus baju lain.
	var views := [
		{"distance": 0.40, "name": "dekat", "yaw": PI, "pitch": 0.18},
		{"distance": 0.50, "name": "leher", "yaw": PI, "pitch": -0.12, "focus": 1.34},
		{"distance": 0.85, "name": "kepala", "yaw": PI, "pitch": 0.18},
		{"distance": 2.20, "name": "badan", "yaw": PI, "pitch": 0.26},
		{"distance": 1.25, "name": "kain", "yaw": PI * 0.5, "pitch": 0.02, "focus": 0.80},
		{"distance": 2.20, "name": "samping", "yaw": PI * 0.5, "pitch": 0.20},
		{"distance": 2.20, "name": "belakang", "yaw": 0.0, "pitch": 0.20},
	]
	for view: Dictionary in views:
		orbit.distance = float(view["distance"])
		orbit.yaw = float(view["yaw"])
		orbit.pitch = float(view["pitch"])
		orbit.focus_offset = Vector3(0.0, float(view.get("focus", 0.55)), 0.0)
		await _capture("avatar-%s" % view["name"])
	# Pose bergerak HARUS lewat joystick: kalau klip dipanggil langsung, pemain
	# menimpanya lagi tiap frame dan semua gambar jadi pose diam (kejadian di
	# versi pertama tes ini — HUD-nya masih tertulis Idle_Loop).
	var player: CharacterBody3D = game.get("_player")
	var stick: Control = game.get("_joystick")
	var visual: Node = game.get("_visual")
	orbit.focus_offset = Vector3(0.0, 0.55, 0.0)
	orbit.yaw = PI * 0.5
	stick.set("direction", Vector2.UP)
	for frame in range(90):
		await physics_frame
	await _capture("avatar-jalan")
	player.set("boosted", true)
	for frame in range(90):
		await physics_frame
	await _capture("avatar-lari")
	player.set("boosted", false)
	stick.set("direction", Vector2.ZERO)
	for frame in range(60):
		await physics_frame
	# Jongkok: lewat tombol pemain juga, supaya animasinya konsisten.
	player.toggle_crouch()
	stick.set("direction", Vector2.UP)
	for frame in range(60):
		await physics_frame
	await _capture("avatar-jongkok")
	stick.set("direction", Vector2.ZERO)
	player.toggle_crouch()
	for frame in range(30):
		await physics_frame
	print("[avatar-render-test] klip terakhir: ", visual.get("clip"))

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
