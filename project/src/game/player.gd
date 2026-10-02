extends CharacterBody3D
## Pemain di pulau 1 km. Gerak mengikuti animasi, bukan sebaliknya.
##
## Satu keputusan gait per frame dipakai bersama oleh badan dan animasi:
##   kecepatan input → gait (dengan histeresis) → kecepatan alami klip × skala
## Karena badan bergerak tepat secepat yang dimaksud klipnya, kaki tidak
## meluncur. Inilah perbaikan utama dibanding versi lama yang menaikkan
## speed_scale sembarangan (mis. ×3 saat boost) lalu membiarkan langkah meluncur.

const Character = preload("res://src/game/mannequin.gd")
const Field = preload("res://src/game/world/field.gd")
const Joystick = preload("res://src/game/virtual_joystick.gd")
const Orbit = preload("res://src/game/orbit_camera.gd")

const HEIGHT := 1.8
const RADIUS := 0.3
const GRAVITY := 20.0
const JUMP_VELOCITY := 7.0
## Pose tolakan hanya sekejap; setelah itu klip melayang (loop) mengambil alih.
const JUMP_POSE_TIME := 0.16
## Di udara laju lari TIDAK dibuang: hanya arahnya yang boleh dikoreksi dan itu
## pun lembut. Kalau tidak, jempol yang lepas dari analog saat menekan LOMPAT
## membuat badan mengerem di udara, mendarat pelan, lalu memutar pose mendarat —
## persis "berhenti sekejap, jongkok dulu, baru jalan lagi".
const AIR_STEER := 6.0
## Tambahan laju di udara hanya untuk lompatan dari diam (badan boleh mengejar
## input), dan lebih pelan daripada di darat supaya lompatan lari tetap terasa.
const AIR_ACCEL := 4.0
## Di atas kecepatan ini barulah klip jalan dipakai; di bawahnya Idle. Tanpa batas
## ini, pemain yang sudah berhenti tetap memutar klip jalan (jalan di tempat).
const IDLE_EXIT := 0.20
## Kalau menyentuh tanah sambil masih bergerak (lari/jalan), klip mendarat
## DILEWATI: badannya langsung nyambung ke klip lari lagi. Klip mendarat berpose
## seperti jongkok-menyerap, dan itulah yang terlihat seperti "jeda patung" di
## tengah lari. Klip mendarat hanya dipakai untuk pendaratan pelan/diam.
const LANDING_SKIP_SPEED := 1.2
## Combo serangan: tiap tekan tombol lanjut ke klip berikutnya lalu berulang.
const ATTACK_COMBO := ["Punch_Jab", "Punch_Cross", "Melee_Hook"]
const COMBO_RESET := 1.1
const ACCEL := 16.0
const TURN_SPEED := 13.0
const BOOST_MULTIPLIER := 1.35
const MAX_SPEED := 5.2
const CROUCH_SPEED := 1.2
const SCALE_MIN := 0.62
const SCALE_MAX := 1.5
const SCALE_MAX_BOOST := 2.05
const HYSTERESIS := 0.35
## Jarak minimum pemain dari garis pantai (meter). Tanjakan pantai 6 m / 70 m,
## jadi 14 m ke dalam berarti ± 1,2 m di atas permukaan air: pemain berhenti di
## pasir kering, tidak berdiri tenggelam sampai mata kaki.
const SHORE_MARGIN := 14.0
const FALL_RESET := -12.0
const IDLE := "Idle_Loop"
const AIR_FALL := "Jump_Loop"
const JUMP_START := "Jump_Start"
const JUMP_LAND := "Jump_Land"
const CROUCH_IDLE := "Crouch_Idle_Loop"
const CROUCH_WALK := "Crouch_Fwd_Loop"

## Band kecepatan tiap klip lokomosi (m/s). Histeresis menjaga tidak berkedip
## saat kecepatan berada tepat di batas band.
const GAITS := [
	{"clip": IDLE, "min": 0.0, "max": 0.15},
	{"clip": "Walk_Loop", "min": 0.15, "max": 2.2},
	{"clip": "Jog_Fwd_Loop", "min": 2.2, "max": 4.4},
	{"clip": "Sprint_Loop", "min": 4.4, "max": MAX_SPEED * BOOST_MULTIPLIER + 1.0},
]

var joystick: Joystick
var orbit: Orbit
var field: Field
var visual: Character
var crouching := false
var boosted := false
var move_speed := 0.0
var speed_scale := 1.0
var gait := IDLE
var grounded := true
var combo_index := 0
var _airborne := false
var _air_time := 0.0
var _combo_timer := 0.0


func _ready() -> void:
	name = "Player"
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(50)
	slide_on_ceiling = false
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	shape.shape = capsule
	add_child(shape)


func spawn(point: Vector2) -> void:
	var ground := field.surface_height(point.x, point.y)
	global_position = Vector3(point.x, ground + HEIGHT * 0.5 + 0.05, point.y)
	velocity = Vector3.ZERO
	gait = IDLE
	if visual != null:
		visual.set_locomotion(IDLE, 1.0)


func request_jump() -> void:
	# Langsung melompat: dorongan dipasang saat itu juga, pose tolakan hanya
	# menempel di badan yang sudah naik. Tidak ada jeda menahan pemain.
	if _airborne or not is_on_floor():
		return
	velocity.y = JUMP_VELOCITY
	_airborne = true
	_air_time = 0.0
	if visual != null:
		visual.play_action(JUMP_START)


func attack() -> String:
	# Combo: tiap tekan ganti klip serangan, sama seperti game aksi lain.
	if visual == null:
		return ""
	var clip: String = ATTACK_COMBO[combo_index]
	combo_index = (combo_index + 1) % ATTACK_COMBO.size()
	_combo_timer = COMBO_RESET
	visual.play_action(clip)
	return clip


func toggle_crouch() -> void:
	crouching = not crouching


func toggle_boost() -> void:
	boosted = not boosted


func _physics_process(delta: float) -> void:
	if field == null or visual == null:
		return
	var stick := Vector2.ZERO
	if joystick != null and joystick.input_enabled:
		stick = joystick.direction
	if _combo_timer > 0.0:
		_combo_timer = maxf(0.0, _combo_timer - delta)
		if _combo_timer <= 0.0:
			combo_index = 0
	var desired := _desired_speed(stick)
	# Gait ikut laju badan yang sebenarnya, bukan cuma input: begitu analog
	# dilepas, badan yang masih meluncur tidak boleh langsung berpose Idle —
	# itulah "berhenti sekejap" yang terlihat. Badan melambat lewat klip
	# Sprint -> Jog -> Walk -> Idle, sama seperti kakinya.
	gait = select_gait(maxf(desired, move_speed), gait)
	var target := _target_velocity(stick, desired)
	var flat := Vector2(velocity.x, velocity.z)
	var blended := flat
	if _airborne:
		# Di udara badan tidak mengerem sendiri: laju saat menolak dibawa sampai
		# mendarat. Arah masih bisa dikoreksi, dan lompatan dari diam tetap boleh
		# mengejar input (lebih pelan daripada di darat).
		var speed := flat.length()
		var wish := Vector2(target.x, target.z)
		if wish.length() > speed:
			blended = flat.lerp(wish, 1.0 - exp(-AIR_ACCEL * delta))
		elif speed > 0.05 and wish.length() > 0.01:
			# Putar arah saja, panjangnya tetap — tidak ada frame yang menoleh
			# lewat titik nol lalu berhenti sekejap di udara.
			blended = flat.rotated(clampf(flat.angle_to(wish),
				-AIR_STEER * delta, AIR_STEER * delta))
	else:
		blended = flat.lerp(Vector2(target.x, target.z), 1.0 - exp(-ACCEL * delta))
	# Saat baru menolak, badan masih menempel lantai satu frame — kalau kecepatan
	# vertikalnya dinolkan di sini, lompatannya langsung hilang.
	var rising := _airborne and velocity.y > 0.0
	if is_on_floor() and not rising:
		velocity = Vector3(blended.x, 0.0, blended.y)
	else:
		velocity = Vector3(blended.x, velocity.y - GRAVITY * delta, blended.y)
	move_speed = Vector2(velocity.x, velocity.z).length()
	move_and_slide()
	_keep_inside()
	_update_air_state(delta)
	_apply_animation(desired)
	if move_speed > 0.05 and grounded:
		var facing := atan2(-velocity.x, -velocity.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, facing,
			1.0 - exp(-TURN_SPEED * delta))


func _desired_speed(stick: Vector2) -> float:
	var strength := minf(stick.length(), 1.0)
	if strength < 0.02:
		return 0.0
	var speed := MAX_SPEED * strength
	if boosted:
		speed *= BOOST_MULTIPLIER
	if crouching:
		speed = minf(speed, CROUCH_SPEED)
	return speed


func _target_velocity(stick: Vector2, desired: float) -> Vector3:
	if desired <= 0.02 or field == null:
		speed_scale = 1.0
		return Vector3.ZERO
	var direction := orbit.movement_direction(stick)
	var natural := visual.natural_speed(gait)
	speed_scale = clampf(desired / natural, SCALE_MIN,
		SCALE_MAX_BOOST if boosted else SCALE_MAX)
	return direction * natural * speed_scale


func _apply_animation(desired: float) -> void:
	# Di udara, animasi melayang selalu menang: klip tolakan/mendarat yang panjang
	# tidak boleh mengunci badan sampai terlihat berhenti.
	if _airborne:
		if visual.gait != AIR_FALL and _air_time >= JUMP_POSE_TIME:
			visual.set_air_clip(AIR_FALL, 1.0)
		return
	# Aksi sekali jalan dan klip pilihan panel tidak boleh ditimpa.
	if visual.is_busy():
		return
	# Klip gait mengikuti laju badan (bukan cuma input tekanan analog): saat
	# meluncur berhenti setelah berlari, kaki tetap mengayun secepat badan.
	var reference := maxf(desired, move_speed)
	var scale := 1.0
	if reference > 0.05:
		scale = clampf(reference / visual.natural_speed(gait), SCALE_MIN,
			SCALE_MAX_BOOST if boosted else SCALE_MAX)
	visual.set_locomotion(gait, scale)


func _band_for(speed: float) -> String:
	for entry in GAITS:
		if speed >= float(entry["min"]) and speed <= float(entry["max"]):
			return str(entry["clip"])
	return "Sprint_Loop"


func select_gait(speed: float, current: String) -> String:
	if crouching:
		return CROUCH_WALK if speed > 0.12 else CROUCH_IDLE
	var target := _band_for(speed)
	if target == current:
		return current
	# Histeresis menahan klip supaya tidak berkedip di ambang antarband lari.
	# Band Idle TIDAK diperpanjang ke bawah dan band jalan tidak boleh turun
	# sampai nol: kalau boleh, pemain yang sudah berhenti tetap memutar klip
	# jalan — kelihatan seperti jalan di tempat meski badan diam.
	if current == IDLE:
		return current if speed <= IDLE_EXIT else target
	for entry in GAITS:
		if str(entry["clip"]) != current:
			continue
		var low := maxf(float(entry["min"]) - HYSTERESIS, IDLE_EXIT)
		if speed >= low and speed <= float(entry["max"]) + HYSTERESIS:
			return current
	return target


func _update_air_state(delta: float) -> void:
	grounded = is_on_floor()
	if not _airborne:
		return
	_air_time += delta
	# Mendarat hanya sah saat badan benar-benar turun; kalau tidak, frame pertama
	# setelah tolakan (yang masih menempel lantai) akan salah dibaca sebagai mendarat.
	if grounded and velocity.y <= 0.0:
		_airborne = false
		_air_time = 0.0
		if move_speed <= LANDING_SKIP_SPEED:
			# Pendaratan pelan/diam: klip mendarat sebentar, lalu lanjut gait.
			visual.play_landing(JUMP_LAND)
		# Kalau masih berlari, tidak ada yang perlu dilakukan: frame yang sama
		# langsung memanggil set_locomotion(gait) di _apply_animation, jadi
		# lari -> lompat -> lari tersambung tanpa jeda dan tanpa pose jongkok.
	elif not visual.is_busy() and visual.gait != AIR_FALL:
		visual.set_air_clip(AIR_FALL, 1.1)


func _keep_inside() -> void:
	# Batas pulau adalah GARIS PANTAI, bukan kotak: pemain tidak boleh berenang
	# keluar. Kalau ia keluar (tergelincur turun tanjakan), ia didorong kembali
	# ke titik terdekat yang masih di darat lewat proyeksi radial.
	if field != null and not Field.is_inside(global_position.x, global_position.z,
			SHORE_MARGIN):
		var fixed := Field.clamp_inside(
			Vector2(global_position.x, global_position.z), SHORE_MARGIN)
		global_position.x = fixed.x
		global_position.z = fixed.y
		velocity.x = 0.0
		velocity.z = 0.0
	if global_position.y < FALL_RESET:
		spawn(Vector2.ZERO)
