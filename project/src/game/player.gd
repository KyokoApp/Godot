extends CharacterBody3D
## Pemain di padang 100 m. Gerak mengikuti animasi, bukan sebaliknya.
##
## Satu keputusan gait per frame dipakai bersama oleh badan dan animasi:
##   kecepatan input → gait (dengan histeresis) → kecepatan alami klip × skala
## Karena badan bergerak tepat secepat yang dimaksud klipnya, kaki tidak
## meluncur. Inilah perbaikan utama dibanding versi lama yang menaikkan
## speed_scale sembarangan (mis. ×3 saat boost) lalu membiarkan langkah meluncur.

const Mannequin = preload("res://src/game/mannequin.gd")
const Field = preload("res://src/game/world/field.gd")
const Joystick = preload("res://src/game/virtual_joystick.gd")
const Orbit = preload("res://src/game/orbit_camera.gd")

const HEIGHT := 1.8
const RADIUS := 0.3
const GRAVITY := 20.0
const JUMP_VELOCITY := 7.0
## Pose tolakan hanya sekejap; setelah itu klip melayang yang mengambil alih.
const JUMP_POSE_TIME := 0.30
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
const BOUNDARY := 0.9
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
var visual: Mannequin
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
	gait = select_gait(desired, gait)
	var target := _target_velocity(stick, desired)
	var blended := Vector2(velocity.x, velocity.z).lerp(
		Vector2(target.x, target.z), 1.0 - exp(-ACCEL * delta))
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
	# Aksi sekali jalan dan klip pilihan panel tidak boleh ditimpa.
	if visual.is_busy():
		return
	if _airborne:
		# Pose tolakan hanya sebentar; setelah itu klip melayang.
		if visual.gait != AIR_FALL and _air_time > JUMP_POSE_TIME:
			visual.set_air_clip(AIR_FALL, 1.1)
		return
	var scale := 1.0
	if desired > 0.02:
		scale = clampf(desired / visual.natural_speed(gait), SCALE_MIN,
			SCALE_MAX_BOOST if boosted else SCALE_MAX)
	visual.set_locomotion(gait, scale)


func select_gait(speed: float, current: String) -> String:
	if crouching:
		return CROUCH_WALK if speed > 0.12 else CROUCH_IDLE
	for entry in GAITS:
		if entry["clip"] == current:
			var low: float = entry["min"] - HYSTERESIS
			var high: float = entry["max"] + HYSTERESIS
			if speed >= low and speed <= high:
				return current
	for entry in GAITS:
		if speed >= float(entry["min"]) and speed <= float(entry["max"]):
			return entry["clip"]
	return "Sprint_Loop"


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
		visual.play_action(JUMP_LAND)
	elif not visual.is_busy() and visual.gait != AIR_FALL:
		visual.set_air_clip(AIR_FALL, 1.1)


func _keep_inside() -> void:
	var limit := Field.HALF - BOUNDARY
	if absf(global_position.x) > limit:
		global_position.x = clampf(global_position.x, -limit, limit)
		velocity.x = 0.0
	if absf(global_position.z) > limit:
		global_position.z = clampf(global_position.z, -limit, limit)
		velocity.z = 0.0
	if global_position.y < FALL_RESET:
		spawn(Vector2.ZERO)
