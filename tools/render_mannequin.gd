extends SceneTree
## Render mannequin (dengan kulit beranimasinya) dari kamera pemain pada
## beberapa jarak, lalu simpan
## sebagai PNG untuk diperiksa mata (dan dikirim sebagai pratinjau di CI).
##
## Kenapa ada tes ini: hasil akhir "kulit" tidak bisa dinilai dari angka —
## apakah tulang/sambungan mannequin benar-benar tertutup hanya terlihat dari
## gambar. Jarak 0,4 m = zoom terdekat yang dipakai pemain, jadi itu yang
## dirender lebih dulu. Sudut belakang/samping penting untuk melihat apakah ada
## bagian mesh dalam yang menonjol keluar kulit.

const Catalog = preload("res://src/game/animation/catalog.gd")
const Orbit = preload("res://src/game/orbit_camera.gd")
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
	# api, sinar matahari): yang diperiksa di sini avatar-nya, bukan efeknya.
	for node_name in ["_pet", "_speed_aura", "_foot_fire", "_shafts", "_banner"]:
		var effect: Node = game.get(node_name)
		if effect != null:
			effect.set("visible", false)
			effect.set_process(false)
	# Sudut & jarak: depan untuk wajah, samping untuk kain, belakang untuk
	# rambut belakang dan rok (di situlah tembus badan paling terlihat).
	# "leher": kamera sedikit dari bawah, karena leher hanya terlihat jelas dari
	# arah itu. "kain"/"kain_belakang": jarak sedang, untuk menilai kain yang
	# kaku atau menembus baju lain. Titik bidik diambil dari TULANG (bukan angka
	# meter yang ditebak): skala impor FBX sempat membuat bidikan leher mengarah
	# ke langit.
	var player: CharacterBody3D = game.get("_player")
	var stick: Control = game.get("_joystick")
	var visual: Node = game.get("_visual")
	var avatar: Skeleton3D = visual.get("avatar") if visual != null else null
	var views := [
		{"distance": 0.40, "name": "dekat", "yaw": PI, "pitch": 0.18},
		{"distance": 0.45, "name": "leher", "yaw": PI, "pitch": -0.10, "bone": "neck_01",
			"lift": 0.02},
		{"distance": 0.85, "name": "kepala", "yaw": PI, "pitch": 0.18},
		{"distance": 2.20, "name": "badan", "yaw": PI, "pitch": 0.26},
		{"distance": 1.40, "name": "kain", "yaw": PI * 0.5, "pitch": 0.04,
			"bone": "pelvis", "lift": 0.05},
		{"distance": 1.30, "name": "kain_belakang", "yaw": PI * 0.25, "pitch": 0.06,
			"bone": "spine_01", "lift": 0.05},
		{"distance": 1.05, "name": "bokong", "yaw": 0.0, "pitch": 0.02,
			"bone": "pelvis", "lift": 0.0},
		{"distance": 2.20, "name": "samping", "yaw": PI * 0.5, "pitch": 0.20},
		{"distance": 2.20, "name": "belakang", "yaw": 0.0, "pitch": 0.20},
	]
	for view: Dictionary in views:
		orbit.distance = float(view["distance"])
		orbit.yaw = float(view["yaw"])
		orbit.pitch = float(view["pitch"])
		orbit.focus_offset = Vector3(0.0, _focus_height(view, player, avatar), 0.0)
		await _capture("avatar-%s" % view["name"])
	_report_heights(player, avatar)
	# Pose bergerak HARUS lewat joystick: kalau klip dipanggil langsung, pemain
	# menimpanya lagi tiap frame dan semua gambar jadi pose diam (kejadian di
	# versi pertama tes ini — HUD-nya masih tertulis Idle_Loop).
	# Pose bergerak dibidik PINGGUL dan jaraknya dekat: kalau kamera jauh di
	# setinggi kepala, kain cuma jadi beberapa piksel dan tidak bisa dinilai.
	var hips := {"bone": "pelvis", "lift": 0.05}
	orbit.focus_offset = Vector3(0.0, _focus_height(hips, player, avatar), 0.0)
	orbit.yaw = PI * 0.5
	orbit.pitch = 0.06
	orbit.distance = 1.80
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
	# Jongkok: lewat tombol pemain juga, supaya animasinya konsisten. Dua pose
	# direkam: DIAM jongkok (yang dikeluhkan "kayak difoto") dan merangkak maju —
	# tanpa keduanya, tidak bisa dibedakan klipnya diam atau kainnya kaku.
	player.toggle_crouch()
	orbit.yaw = PI * 0.25
	orbit.pitch = 0.06
	orbit.distance = 1.55
	for frame in range(70):
		await physics_frame
	await _capture("avatar-jongkok")
	stick.set("direction", Vector2.UP)
	for frame in range(70):
		await physics_frame
	await _capture("avatar-jongkok_jalan")
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


## Tinggi bidik kamera (relatif ke pemain): 0,55 m seperti di permainan, atau
## tinggi tulang yang disebut view. Dipakai supaya bidikan tidak bergantung pada
## skala impor FBX.
func _focus_height(view: Dictionary, player: Node3D, avatar: Skeleton3D) -> float:
	if avatar == null or player == null or not view.has("bone"):
		return 0.55
	var bone := avatar.find_bone(str(view["bone"]))
	if bone < 0:
		return 0.55
	var world := (avatar.global_transform * avatar.get_bone_global_pose(bone)).origin.y
	return world - player.global_position.y + float(view.get("lift", 0.0))


## Tinggi tulang penting dalam dunia — dipakai untuk memastikan skala avatar
## (skala impor FBX pernah membuat perhitungan bidikan salah).
func _report_heights(player: Node3D, avatar: Skeleton3D) -> void:
	if avatar == null or player == null:
		return
	# Nama tulang rig UAL (bukan Biped): head/neck_01.
	var neck := avatar.find_bone("neck_01")
	var head := avatar.find_bone("Head")
	if neck < 0 or head < 0:
		return
	var neck_y := (avatar.global_transform * avatar.get_bone_global_pose(neck)).origin.y
	var head_y := (avatar.global_transform * avatar.get_bone_global_pose(head)).origin.y
	print("::notice::tinggi avatar: pemain=%.3f leher=%.3f kepala=%.3f" % [
		player.global_position.y, neck_y, head_y])


func _capture(name: String) -> void:
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "user://%s-test.png" % name
	image.save_png(path)
	print("[avatar-render-test] ", path, " ", image.get_width(), "x", image.get_height())
