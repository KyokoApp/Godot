extends Node3D
## Bounded world-space SFX, camera listener, sparse terrain occlusion checks.

const Voice = preload("res://src/game/audio/sound_voice.gd")
const SHOOT = preload("res://assets/audio/fire_shoot.wav")
const EXPLODE = preload("res://assets/audio/fire_explode.wav")
const FIRE = preload("res://assets/audio/fire_loop.wav")
const BUS := "WorldSFX"
const MAX_VOICES := 16

var listener: Camera3D
var voices: Array[Voice] = []
var _banks: Dictionary[String, Array] = {}
var _last: Dictionary[String, int] = {}
var _random := RandomNumberGenerator.new()
var _occlusion_clock := 0.0
var _owns_bus := false
var _loop: AudioStreamWAV


func _ready() -> void:
	add_to_group("world_audio")
	_random.randomize()
	if AudioServer.get_bus_index(BUS) < 0:
		_owns_bus = true
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, BUS)
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db = -1.0
		limiter.threshold_db = -3.0
		AudioServer.add_bus_effect(index, limiter)
	_loop = FIRE.duplicate() as AudioStreamWAV
	_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_loop.loop_begin = 0
	_loop.loop_end = int(_loop.get_length() * _loop.mix_rate)
	for kind in ["grass", "dirt", "stone"]:
		var bank: Array[AudioStream] = []
		for index in range(4):
			bank.append(load("res://assets/audio/step_%s_%d.wav" % [kind, index]))
		_banks[kind] = bank
	for index in range(MAX_VOICES):
		var voice := Voice.new()
		voice.bus = BUS
		voice.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		voice.unit_size = 4.0
		voice.max_db = 0.0
		voice.panning_strength = 1.0
		add_child(voice)
		voices.append(voice)


func _acquire() -> Voice:
	for voice in voices:
		if not voice.playing:
			return voice
	# Retire quiet transient first, never steal the companion's continuous fire.
	var oldest: Voice
	for voice in voices:
		if not voice.following and (oldest == null or voice.age > oldest.age):
			oldest = voice
	if oldest != null:
		oldest.stop()
	return oldest


func play_at(stream: AudioStream, point: Vector3, db: float, reach: float,
		pitch := 1.0) -> Voice:
	if listener != null and listener.global_position.distance_to(point) > reach:
		return null
	var voice := _acquire()
	if voice == null:
		return null
	voice.following = false
	voice.flying = false
	voice.source = null
	voice.age = 0
	voice.obstruction = 0
	voice.target_obstruction = 0
	voice.base_db = db
	voice.volume_db = db
	voice.attenuation_filter_cutoff_hz = 12000
	voice.attenuation_filter_db = -18
	voice.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	voice.max_distance = reach
	voice.global_position = point
	voice.stream = stream
	voice.pitch_scale = pitch
	voice.play()
	return voice


func shoot(point: Vector3) -> void:
	play_at(SHOOT, point, -10, 65, _random.randf_range(0.96, 1.04))


func explode(point: Vector3) -> void:
	play_at(EXPLODE, point, -5, 140, _random.randf_range(0.94, 1.04))


func follow_fire(source: Node3D, flying := false) -> void:
	var voice := play_at(_loop, source.global_position, -24 if flying else -32, 28)
	if voice == null:
		return
	voice.source = source
	voice.following = true
	voice.flying = flying
	voice.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP


func footstep(point: Vector3, surface: String, speed: float, landing := false) -> void:
	var previous := _last.get(surface, -1) as int
	var selection := _random.randi_range(0, 2)
	if selection >= previous and previous >= 0:
		selection += 1
	_last[surface] = selection
	var loudness := lerpf(-20, -14, clampf(speed / 5.0, 0, 1))
	play_at(_banks[surface][selection], point, loudness + (3 if landing else 0),
		24, _random.randf_range(0.94, 1.06))


func _physics_process(delta: float) -> void:
	_occlusion_clock += delta
	var check_walls := _occlusion_clock >= 0.12
	if check_walls:
		_occlusion_clock = 0
	for voice in voices:
		if not voice.playing:
			continue
		voice.age += delta
		if voice.following:
			if not is_instance_valid(voice.source):
				voice.stop()
				continue
			if voice.flying and voice.source.get("finished"):
				voice.stop()
				continue
			voice.global_position = voice.source.global_position
		elif voice.age > 4:
			voice.stop()
		if listener == null:
			continue
		var distance := listener.global_position.distance_to(voice.global_position)
		if check_walls:
			var query := PhysicsRayQueryParameters3D.create(listener.global_position,
				voice.global_position, 1)
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			voice.target_obstruction = 0.0 if hit.is_empty() else 1.0
		voice.obstruction = lerpf(voice.obstruction, voice.target_obstruction,
			1.0 - exp(-10.0 * delta))
		voice.volume_db = voice.base_db - voice.obstruction * 10.0
		var air := lerpf(12000, 2200, clampf(distance / voice.max_distance, 0, 1))
		voice.attenuation_filter_cutoff_hz = lerpf(air, 1400, voice.obstruction)


func _exit_tree() -> void:
	if _owns_bus:
		AudioServer.remove_bus(AudioServer.get_bus_index(BUS))
