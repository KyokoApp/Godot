extends SceneTree
## Render pemandangan dunia dari beberapa sudut lebar, supaya bisa dinilai mata
## apakah sudah mirip ilustrasi layar muat (bukit, tebing, laut, jalan,
## reruntuhan, titik cahaya). Angka tidak bisa menilai "mirip", jadi gambar ini
## yang dikirim ke komentar commit CI.
##
## Lima sudut dipilih untuk menilai PULAU 100 m (permintaan: dunia 100 m, sisinya
## bergelombang seperti pulau — jangan bulat, jangan kotak):
##   * "pulau"       : seluruh pulau dari udara — ini yang menjawab "bulat/kotak?"
##   * "pemandangan" : dari dataran menghadap garis pantai dan laut
##   * "pantai"      : pita pasir dan garis air dari dekat
##   * "jalan"       : sejajar jalan tanah, seperti pemain berjalan pulang
##   * "laut"        : menyusuri garis pantai: bukit, tebing, dan ufuk senja
##
## Kamera orbit BERDIRI di arah (sin yaw, 0, cos yaw) dari titik bidik dan
## melihat ke arah SEBALIKNYA. Jadi untuk "melihat ke laut" dari titik pantai
## pada sudut theta: yaw = -(theta + PI/2).

const Orbit = preload("res://src/game/orbit_camera.gd")
const Field = preload("res://src/game/world/field.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game: Node3D = load("res://src/game/main.tscn").instantiate()
	root.add_child(game)
	for _frame in range(90):
		await physics_frame
		if (game.get("_player") as CharacterBody3D).is_on_floor():
			break
	var orbit: Orbit = game.get("_orbit")
	if orbit == null:
		print("::error::kamera orbit tidak ditemukan")
		quit(1)
		return
	orbit.exclusions = []
	# Efek yang menutupi pandangan disembunyikan; yang dinilai di sini dunianya.
	for node_name in ["_pet", "_speed_aura", "_foot_fire", "_banner"]:
		var effect: Node = game.get(node_name)
		if effect != null:
			effect.set("visible", false)
			effect.set_process(false)
	var player: CharacterBody3D = game.get("_player")
	# Titik pantai diambil dari bentuk pulau sendiri (bukan ditebak), supaya
	# gambar selalu berdiri di garis air meski garis pantainya berubah.
	var shore_angle := 2.4
	var shore := Vector3(cos(shore_angle), 0.0, sin(shore_angle)) \
		* (Field.island_radius(shore_angle) - 6.0)
	var outward := -(shore_angle + PI * 0.5)
	var views := [
		# Seluruh pulau dari udara: kamera tinggi di timur laut, melihat ke
		# barat daya. Inilah gambar yang menjawab "bulat atau kotak?".
		{"name": "pulau", "distance": 62.0, "yaw": PI * 0.25, "pitch": 1.10,
			"offset": Vector3(0.0, 40.0, 0.0)},
		# Dari dataran menghadap garis pantai dan laut.
		{"name": "pemandangan", "distance": 55.0, "yaw": outward, "pitch": 0.22,
			"offset": shore * 0.55 + Vector3(0.0, 4.0, 0.0)},
		# Pita pasir dan garis air dari dekat.
		{"name": "pantai", "distance": 26.0, "yaw": outward + 0.35, "pitch": 0.16,
			"offset": shore + Vector3(0.0, 3.0, 0.0)},
		# Sejajar jalan tanah: jalannya melintas tepat di titik spawn (0, 7) dan
		# menanjak 0,70 m ke utara tiap meter ke timur, jadi kamera diambil
		# searah (yaw 0,96) supaya jalannya lurus di tengah layar.
		{"name": "jalan", "distance": 16.0, "yaw": 0.96, "pitch": 0.08,
			"offset": Vector3(0.0, 3.0, 0.0)},
		# Menyusuri garis pantai: bukit, tebing, dan ufuk senja.
		{"name": "laut", "distance": 90.0, "yaw": outward + PI * 0.5,
			"pitch": 0.30, "offset": shore + Vector3(0.0, 10.0, 0.0)},
	]
	for view: Dictionary in views:
		orbit.focus_offset = view["offset"]
		orbit.distance = float(view["distance"])
		orbit.yaw = float(view["yaw"])
		orbit.pitch = float(view["pitch"])
		for _frame in range(30):
			await physics_frame
		await _capture("world-%s" % view["name"])
	var scenery: Node = game.get("_scenery")
	print("[world-render-test] pemandangan: ",
		"ada" if scenery != null else "TIDAK ADA",
		", bagian=", scenery.get_child_count() if scenery != null else 0)
	print("[world-render-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	game.queue_free()
	for _frame in range(4):
		await process_frame
	quit(0 if _failures == 0 else 1)


func _capture(name: String) -> void:
	for _frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "user://%s-test.png" % name
	image.save_png(path)
	print("[world-render-test] ", path, " ", image.get_width(), "x", image.get_height())
