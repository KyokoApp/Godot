extends SceneTree

const WorldAudio = preload("res://src/game/audio/world_audio.gd")
const Field = preload("res://src/game/world/field.gd")
var _failures := 0
var _audio: WorldAudio
var _capture: AudioEffectCapture


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _energy(point: Vector3) -> Vector2:
	for voice in _audio.voices:
		voice.stop()
	await create_timer(0.10).timeout
	_capture.clear_buffer()
	_audio.play_at(WorldAudio.SHOOT, point, -10, 100)
	await create_timer(0.35).timeout
	var buffer := _capture.get_buffer(_capture.get_frames_available())
	var energy := Vector2.ZERO
	for sample in buffer:
		energy += sample * sample
	return energy / maxf(1, buffer.size())


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	_audio = WorldAudio.new()
	_audio.listener = camera
	world.add_child(_audio)
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 1.0
	var bus := AudioServer.get_bus_index(WorldAudio.BUS)
	AudioServer.add_bus_effect(bus, _capture)
	var near: Vector2 = await _energy(Vector3(0, 0, -4))
	var far: Vector2 = await _energy(Vector3(0, 0, -40))
	_check(near.length() > 0.000001, "Mixer audio diam / sample gagal decode")
	_check(far.length() < near.length() * 0.1, "Suara jauh tidak melemah")
	var left: Vector2 = await _energy(Vector3(-6, 0, -3))
	var right: Vector2 = await _energy(Vector3(6, 0, -3))
	_check(left.x > left.y * 1.1, "Panning kiri tidak bekerja")
	_check(right.y > right.x * 1.1, "Panning kanan tidak bekerja")
	for kind in ["grass", "dirt", "stone"]:
		var previous := -1
		for index in range(8):
			_audio.footstep(Vector3(0, 0, -2), kind, 5)
			var selected: int = _audio.get("_last")[kind]
			_check(selected != previous, "Varian langkah berulang berturut-turut")
			previous = selected
	_check(_audio.voices.size() == WorldAudio.MAX_VOICES, "Pool suara tidak dibatasi")
	for voice in _audio.voices:
		voice.stop()
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.4)
	shape.shape = box
	wall.add_child(shape)
	wall.position = Vector3(0, 0, -5)
	world.add_child(wall)
	await physics_frame
	await physics_frame
	var muffled := _audio.play_at(WorldAudio.EXPLODE, Vector3(0, 0, -10), -5, 140)
	_audio._physics_process(0.15)
	_check(muffled.target_obstruction > 0.9, "Tembok tidak meredam sumber")
	_check(muffled.volume_db < -10, "Occlusion tidak menurunkan volume")
	_check(muffled.attenuation_filter_cutoff_hz < 5000, "Occlusion tidak menyaring treble")
	var source := Node3D.new()
	world.add_child(source)
	_audio.follow_fire(source)
	var pet_voice: AudioStreamPlayer3D
	for voice in _audio.voices:
		if voice.following and voice.source == source:
			pet_voice = voice
	_check(pet_voice != null, "Loop pet tidak dimulai")
	if pet_voice != null:
		_check(pet_voice.stream.get_length() > 7, "Pet masih memakai dengung peluru")
		_check(pet_voice.volume_db == -22, "Level crackle pet berubah")
	source.queue_free()
	await process_frame
	_audio._physics_process(0.15)
	for voice in _audio.voices:
		_check(not (voice.playing and voice.following), "Api bersuara setelah sumber dihapus")
	world.queue_free()
	await process_frame
	_check(AudioServer.get_bus_index(WorldAudio.BUS) < 0, "Bus audio bocor setelah keluar")
	await _test_steps()
	print("[audio-test] near=", near, " far=", far, " left=", left, " right=", right)
	print("[audio-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)


func _test_steps() -> void:
	var scene: PackedScene = load("res://src/game/main.tscn")
	var game: Node3D = scene.instantiate()
	root.add_child(game)
	for frame in range(20):
		await physics_frame
	var footsteps: Node = game.get("_footsteps")
	var stick: Control = game.get("_joystick")
	var player: Node3D = game.get("_player")
	var before: int = footsteps.get("emitted")
	for frame in range(15):
		await physics_frame
	_check(footsteps.get("emitted") == before, "Langkah berbunyi saat diam")
	stick.set("direction", Vector2.RIGHT)
	for frame in range(65):
		await physics_frame
	var walking: int = footsteps.get("emitted")
	_check(walking > before and walking <= before + 7, "Cadence langkah tidak mengikuti gerak")
	stick.set("direction", Vector2.ZERO)
	# Pemain masih melambat setelah jari diangkat; langkah selama benar-benar
	# bergerak itu wajar. Tunggu diam dulu, baru hitung.
	for frame in range(90):
		await physics_frame
		if float(player.get("move_speed")) < 0.05:
			break
	_check(float(player.get("move_speed")) < 0.05, "Pemain tidak berhenti")
	var stopped: int = footsteps.get("emitted")
	for frame in range(20):
		await physics_frame
	_check(footsteps.get("emitted") == stopped, "Langkah tidak berhenti")
	# Pulau 1 km: tengah = rumput, pesisir rendah = pasir/tanah, lereng curam = batu.
	_check(footsteps.surface_at(Vector3(0, 5, 0), Vector3.UP) == "grass",
		"Tengah pulau bukan rumput")
	_check(footsteps.surface_at(Vector3(4, 5, 0), Vector3.UP) == "grass",
		"Dekat tengah sudah berubah jadi tanah")
	# Titik pesisir dicari dari bentuk pulau: tanah di bawah 2,6 m di atas air
	# (batas yang sama dengan pita pasir di ground.gdshader) harus berbunyi tanah.
	var shore := Vector3.ZERO
	var found := false
	for step in range(64):
		var angle := TAU * float(step) / 64.0
		var radius := Field.island_radius(angle) - 1.0
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		if Field.terrain_height(x, z) < 2.6 and Field.terrain_height(x, z) > -1.0:
			shore = Vector3(x, 5, z)
			found = true
			break
	_check(found, "Tidak ada titik pesisir rendah untuk diuji")
	if found:
		_check(footsteps.surface_at(shore, Vector3.UP) == "dirt",
			"Pesisir rendah bukan tanah (pasir)")
	_check(footsteps.surface_at(Vector3(0, 5, 0), Vector3(0, 0.3, 1)) == "stone",
		"Lereng curam bukan batu")
	game.queue_free()
	await process_frame
