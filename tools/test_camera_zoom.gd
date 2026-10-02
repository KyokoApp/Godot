extends SceneTree
## Gerbang zoom kamera: cubit dua jari harus benar-benar bisa menempel ke
## karakter, dan tidak boleh menembus tanah / memotong wajah.
##
## Yang diuji BUKAN "nilai konstanta benar", tapi hasilnya di ruang dunia:
## setelah mencubit, jarak kamera ke tulang kepala harus di bawah satu meter,
## kamera menghadap kepala, bidang dekatnya menyesuaikan, dan saat dijauhkan
## kembali kamera berhenti di batas maksimum.

const Character = preload("res://src/game/character/aurelia_visual.gd")
const Humanoid = preload("res://src/game/animation/humanoid_map.gd")
const Orbit = preload("res://src/game/orbit_camera.gd")
var _failures := 0
var _notes := PackedStringArray()


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
	for frame in range(60):
		await physics_frame
		if (game.get("_player") as CharacterBody3D).is_on_floor():
			break
	var orbit: Orbit = game.get("_orbit")
	var character: Character = game.get("_visual")
	_check(orbit != null and character != null, "Kamera/karakter tidak siap")
	if orbit == null or character == null:
		print("[camera-zoom-test] HASIL: GAGAL")
		game.queue_free()
		quit(1)
		return
	# Tombol HUD diuji terpisah (tools/test_hud.gd); di sini yang diuji zoom, jadi
	# daftar penangkap sentuhan dikosongkan supaya titik cubit tidak kebetulan
	# jatuh di tombol dan membuat hasilnya bergantung tata letak HUD.
	orbit.exclusions = []
	_check(is_equal_approx(orbit.distance, Orbit.DEFAULT_DISTANCE),
		"Jarak kamera awal bukan %.2f m: %.2f" % [Orbit.DEFAULT_DISTANCE, orbit.distance])
	await _test_pinch_in(orbit)
	await _test_camera_geometry(orbit, character)
	_test_wheel(orbit)
	await _test_pinch_out(orbit, character)
	print("[camera-zoom-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	game.queue_free()
	for frame in range(4):
		await process_frame
	quit(0 if _failures == 0 else 1)


## Cubit dua jari pada separuh kanan layar, menjauhkan jari = mendekatkan kamera.
func _pinch(orbit: Orbit, spread_from: float, spread_to: float, steps: int) -> void:
	var size := root.get_visible_rect().size
	var center := Vector2(size.x * 0.75, size.y * 0.5)
	var axis := Vector2(1.0, 0.0)
	orbit._input(_touch(3, center + axis * spread_from, true))
	orbit._input(_touch(7, center + axis * spread_from, true))
	for step in range(1, steps + 1):
		var spread := lerpf(spread_from, spread_to, float(step) / float(steps))
		orbit._input(_drag(3, center + axis * spread))
		orbit._input(_drag(7, center + axis * spread))
	orbit._input(_touch(3, center + axis * spread_to, false))
	orbit._input(_touch(7, center + axis * spread_to, false))


func _touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event


func _drag(index: int, position: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	return event


func _test_pinch_in(orbit: Orbit) -> void:
	var before := orbit.distance
	# Jarak jari 40 px -> 320 px = kamera mendekat 8x.
	_pinch(orbit, 40.0, 320.0, 8)
	_check(orbit.distance < before, "Cubit menjauhkan jari tidak mendekatkan kamera")
	_check(orbit._touches.is_empty(), "Sentuhan tidak dilepas setelah cubit")
	# Cubit terus sampai batas; langkah berlebih memastikan mentok di ujung.
	for round_index in range(20):
		_pinch(orbit, 60.0, 380.0, 6)
	_check(is_equal_approx(orbit.distance, Orbit.MIN_DISTANCE),
		"Zoom terdekat bukan %.2f m: %.2f" % [Orbit.MIN_DISTANCE, orbit.distance])
	# Kamera mengejar titik pandang dengan halus; beri waktu sebelum diukur.
	for frame in range(25):
		await physics_frame


## Setelah menempel: kamera harus dekat ke kepala, menghadap kepala, tidak di
## bawah tanah, dan bidang dekatnya ikut mengecil.
func _test_camera_geometry(orbit: Orbit, character: Character) -> void:
	var camera := orbit.camera
	var head := Humanoid.find_bone(character.avatar, "Bip001 Head")
	_check(head >= 0, "Tulang kepala avatar tidak ditemukan")
	if head < 0:
		return
	var head_point := character.avatar.global_transform \
		* character.avatar.get_bone_global_pose(head)
	var gap := camera.global_position.distance_to(head_point)
	_check(gap < 0.9, "Kamera tidak benar-benar dekat ke kepala: %.2f m" % gap)
	# Arah pandang: kepala harus ada di tengah layar, bukan di pinggir.
	var facing := -camera.global_transform.basis.z.normalized()
	var to_head := (head_point - camera.global_position).normalized()
	_check(facing.dot(to_head) > 0.85,
		"Kepala tidak di tengah pandangan: dot=%.3f" % facing.dot(to_head))
	_check(camera.global_position.y > 0.2,
		"Kamera menembus tanah: y=%.2f m" % camera.global_position.y)
	_check(camera.near <= 0.08, "Bidang dekat belum menyesuaikan: %.3f m" % camera.near)
	_notes.append("dekat: kepala %.2f m, dot=%.3f, near=%.3f, y=%.2f m" % [gap,
		facing.dot(to_head), camera.near, camera.global_position.y])


func _test_wheel(orbit: Orbit) -> void:
	var before := orbit.distance
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	down.pressed = true
	orbit._input(down)
	var want := clampf(before * Orbit.WHEEL_STEP, Orbit.MIN_DISTANCE, Orbit.MAX_DISTANCE)
	_check(is_equal_approx(orbit.distance, want),
		"Roda tetikus tidak sesuai: %.3f (harusnya %.3f)" % [orbit.distance, want])


func _test_pinch_out(orbit: Orbit, character: Character) -> void:
	for round_index in range(20):
		_pinch(orbit, 380.0, 60.0, 6)
	_check(is_equal_approx(orbit.distance, Orbit.MAX_DISTANCE),
		"Zoom terjauh bukan %.2f m: %.2f" % [Orbit.MAX_DISTANCE, orbit.distance])
	for frame in range(25):
		await physics_frame
	# Bidang dekat kembali normal saat jauh, dan kamera tidak menempel lagi.
	_check(orbit.camera.near > 0.09, "Bidang dekat tidak kembali saat jauh: %.3f"
		% orbit.camera.near)
	var head := Humanoid.find_bone(character.avatar, "Bip001 Head")
	var head_point := character.avatar.global_transform \
		* character.avatar.get_bone_global_pose(head)
	var gap := orbit.camera.global_position.distance_to(head_point)
	_check(gap > 4.0, "Kamera tidak menjauh lagi: %.2f m" % gap)
	_notes.append("jauh: kepala %.2f m, near=%.3f" % [gap, orbit.camera.near])
	print("--- diagnostik zoom ---")
	for note in _notes:
		print(note)
