extends CharacterBody3D
## Pemain di pulau 100 m. Gerak mengikuti animasi, bukan sebaliknya.
##
## Satu keputusan gait per frame dipakai bersama oleh badan dan animasi:
##   kecepatan input → gait (band dari kecepatan alami terukur) → skala main
## Badan bergerak secepat yang diminta analog, dan kecepatan main animasi
## disesuaikan supaya kaki tidak meluncur. Dulu kecepatan badan DIPOTONG ikut
## kecepatan alami klip (natural × skala maks 1,5): kalau klip jalannya lambat,
## badan ikut lambat dan analog terasa lemas — itulah "jalan geraknya lambat
## banget". Sekarang badan yang menentukan, animasi yang menyesuaikan diri.

signal attack_started(clip: String)
signal health_changed(value: int)
signal survival_stats_changed

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
## Tiap tap memulai satu gerakan mandiri. Input baru ditolak sampai gerakan aktif selesai.
const PUNCH_ATTACKS := ["Punch_Jab", "Punch_Cross"]
const SWORD_ATTACKS: Array[Dictionary] = [
	{"clip": "Sword_Regular_A", "recovery": "Sword_Regular_A_Rec", "damage": 32},
	{"clip": "Sword_Regular_B", "recovery": "Sword_Regular_B_Rec", "damage": 32},
	{"clip": "Sword_Regular_C", "recovery": "", "damage": 40},
]
const MAX_HEALTH := 100
const DAMAGE_COOLDOWN := 0.50
const ACCEL := 16.0
const TURN_SPEED := 13.0
const BOOST_MULTIPLIER := 1.35
## Kecepatan paling tinggi saat analog penuh. Dinaikkan dari 5,2: dulu kecepatan
## badan DIPOTONG ikut kecepatan alami klip (natural x skala maks 1,5), jadi
## kalau klip jalannya lambat badannya juga lambat dan analog terasa lemas.
const MAX_SPEED := 6.0
## Dash: badan didorong lurus 12 m/s, tapi animasi LARI diperlambat jadi SATU
## langkah besar — kaki melangkah pelan sambil badan melesat, napak lagi tepat
## saat dorongan habis, lalu kecepatan main kembali normal. Klipnya TIDAK diganti
## (tetap gait lari), jadi tidak ada jeda/perpindahan animasi sama sekali.
## Angka dasarnya: siklus Sprint_Loop 0,67 s = satu langkah 0,335 s; dibagi
## DASH_PLAYBACK 0,8 jadi 0,42 s ≈ DASH_TIME 0,40 s.
const DASH_SPEED := 12.0
const DASH_TIME := 0.40
const DASH_PLAYBACK := 0.8
const DASH_COOLDOWN := 0.85
## Jalan mundur pelan memakai klip formal; jog/sprint tetap mengikuti laju.
## UAL tidak punya klip mundur jog/sprint atau strafe kiri/kanan.
const BACKWARD_CLIP := "Walk_Formal_Loop"
const BACKWARD_DOT := -0.35
const CROUCH_SPEED := 1.2
const SCALE_MIN := 0.62
const SCALE_MAX := 1.5
const SCALE_MAX_BOOST := 2.05
## Auto-run tetap di batas kecepatan main lokomosi supaya kaki tidak meluncur.
const RUN_ZONE_MAX_SCALE := SCALE_MAX
const HYSTERESIS := 0.35
## Jarak aman dari bibir pulau 100 m; pemain berhenti di darat, bukan di laut.
const SHORE_MARGIN := 1.4
const FALL_RESET := -12.0
const IDLE := "Idle_Loop"
const AIR_FALL := "Jump_Loop"
const JUMP_START := "Jump_Start"
const JUMP_LAND := "Jump_Land"
const CROUCH_IDLE := "Crouch_Idle_Loop"
const CROUCH_WALK := "Crouch_Fwd_Loop"

## Urutan klip lokomosi dari paling lambat. Batas band TIDAK ditulis sebagai
## angka tetap: dihitung dari kecepatan alami tiap klip yang diukur dari tulang
## kaki (lihat _gait_bands()). Angka tebak bikin kaki meluncur (klip jalan dipakai
## untuk kecepatan lari) atau klip lari dipakai untuk jalan pelan.
const GAIT_CLIPS := ["Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop"]

var joystick: Joystick
var orbit: Orbit
var field: Node3D
var visual: Character
var crouching := false
var boosted := false
var sword_mode := false
var endless_run_active := false
var endless_run_speed := 0.0
var endless_run_direction := Vector3(0.0, 0.0, -1.0)
var world_bounds_enabled := true
var max_health := MAX_HEALTH
var health := MAX_HEALTH
var shield_points := 0
var shield_capacity := 0
var damage_reduction := 0.0
var survival_move_speed_multiplier := 1.0
var move_speed := 0.0
var speed_scale := 1.0
var gait := IDLE
var grounded := true
var punch_attack_index := 0
var sword_attack_index := 0
var dash_cooldown := 0.0
## True selama dorongan dash sedang berjalan. Dipakai main.gd untuk menyalakan
## pita jejak + bloom karakter (efek "blur/glow" ronde 18).
var dashing := false
var _airborne := false
var _air_time := 0.0
var _damage_cooldown := 0.0
var _dash_left := 0.0
var _dash_cooldown := 0.0
var _bands: Array = []


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
	var ground := 0.0
	if field != null and field.has_method("surface_height"):
		ground = float(field.call("surface_height", point.x, point.y))
	global_position = Vector3(point.x, ground + HEIGHT * 0.5 + 0.05, point.y)
	velocity = Vector3.ZERO
	move_speed = 0.0
	endless_run_active = false
	endless_run_speed = 0.0
	endless_run_direction = Vector3(0.0, 0.0, -1.0)
	gait = IDLE
	grounded = true
	_airborne = false
	_air_time = 0.0
	dashing = false
	_dash_left = 0.0
	_dash_cooldown = 0.0
	dash_cooldown = 0.0
	if visual != null:
		visual.return_to_locomotion()
		visual.set_locomotion("Sword_Idle" if sword_mode else IDLE, 1.0)


func begin_endless_run(direction: Vector3, speed: float) -> void:
	if health <= 0:
		return
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() < 0.001:
		flat_direction = Vector3(0.0, 0.0, -1.0)
	endless_run_direction = flat_direction.normalized()
	endless_run_active = true
	set_endless_run_speed(speed)
	boosted = false
	crouching = false
	dashing = false
	_dash_left = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	if visual != null:
		visual.return_to_locomotion()


func set_endless_run_speed(speed: float) -> void:
	endless_run_speed = maxf(0.0, speed)


func end_endless_run() -> void:
	endless_run_active = false
	endless_run_speed = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	move_speed = 0.0


func request_jump() -> void:
	# Lompat boleh memotong ayunan atas tubuh; klip tolakan mengambil alih penuh.
	if _airborne or not is_on_floor() or health <= 0:
		return
	velocity.y = JUMP_VELOCITY
	_airborne = true
	_air_time = 0.0
	if visual != null:
		visual._stop_sword_attack()
		visual.play_action(JUMP_START)


func attack() -> String:
	if visual == null or health <= 0 or _airborne or not grounded or visual.is_busy():
		return ""
	if sword_mode:
		var attack: Dictionary = SWORD_ATTACKS[sword_attack_index]
		var clip := str(attack["clip"])
		var sequence: Array[String] = [clip]
		var recovery := str(attack.get("recovery", ""))
		if not recovery.is_empty():
			sequence.append(recovery)
		if visual._start_sword_attack(sequence) <= 0.0:
			return ""
		sword_attack_index = (sword_attack_index + 1) % SWORD_ATTACKS.size()
		attack_started.emit(clip)
		return clip
	var punch: String = PUNCH_ATTACKS[punch_attack_index]
	if visual.play_action(punch) <= 0.0:
		return ""
	punch_attack_index = (punch_attack_index + 1) % PUNCH_ATTACKS.size()
	attack_started.emit(punch)
	return punch


func set_sword_mode(enabled: bool) -> void:
	sword_mode = enabled
	punch_attack_index = 0
	sword_attack_index = 0
	if visual == null:
		return
	visual._stop_sword_attack()
	visual.set_locomotion("Sword_Idle" if enabled else IDLE, 1.0)
	visual._set_weapon_visible(enabled)


func reset_health() -> void:
	health = max_health
	_damage_cooldown = 0.0
	health_changed.emit(health)
	survival_stats_changed.emit()


func heal(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	var healed := mini(max_health, health + amount)
	if healed == health:
		return
	health = healed
	health_changed.emit(health)
	survival_stats_changed.emit()


func set_survival_bonuses(health_bonus: int, shield_capacity_value: int,
		shield_refill: int, reduction: float, speed_multiplier: float = 1.0) -> void:
	var previous_maximum := max_health
	max_health = MAX_HEALTH + maxi(0, health_bonus)
	if max_health > previous_maximum and health > 0:
		health = mini(max_health, health + max_health - previous_maximum)
	else:
		health = mini(health, max_health)
	shield_capacity = maxi(0, shield_capacity_value)
	if shield_refill > 0:
		shield_points = mini(shield_capacity, shield_points + shield_refill)
	else:
		shield_points = mini(shield_points, shield_capacity)
	damage_reduction = clampf(reduction, 0.0, 0.6)
	survival_move_speed_multiplier = clampf(speed_multiplier, 1.0, 1.35)
	health_changed.emit(health)
	survival_stats_changed.emit()


func clear_survival_bonuses() -> void:
	set_survival_bonuses(0, 0, 0, 0.0, 1.0)


func grant_shield(amount: int) -> void:
	if amount <= 0 or shield_capacity <= 0:
		return
	var previous := shield_points
	shield_points = mini(shield_capacity, shield_points + amount)
	if shield_points != previous:
		survival_stats_changed.emit()


func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0 or _damage_cooldown > 0.0:
		return
	var remaining := maxi(1, roundi(amount * (1.0 - clampf(damage_reduction, 0.0, 0.6))))
	if shield_points > 0:
		var absorbed := mini(shield_points, remaining)
		shield_points -= absorbed
		remaining -= absorbed
	_damage_cooldown = DAMAGE_COOLDOWN
	survival_stats_changed.emit()
	if remaining <= 0:
		return
	health = maxi(0, health - remaining)
	health_changed.emit(health)
	if health <= 0:
		velocity = Vector3.ZERO
		if visual != null:
			visual.play_action("Death01")


func request_dash() -> bool:
	# Dash lurus sebentar. Arah mengikuti analog (relatif kamera); kalau analog
	# dilepas, memakai arah laju badan yang sekarang. Tidak bisa di udara.
	if _dash_cooldown > 0.0 or _airborne or visual == null:
		return false
	var direction := Vector3.ZERO
	var stick := Vector2.ZERO
	if joystick != null and joystick.input_enabled:
		stick = joystick.direction
	if stick.length() > 0.15 and orbit != null:
		direction = orbit.movement_direction(stick)
	elif Vector2(velocity.x, velocity.z).length() > 0.3:
		direction = Vector3(velocity.x, 0.0, velocity.z).normalized()
	if direction.length() < 0.05:
		return false
	direction.y = 0.0
	direction = direction.normalized()
	_dash_left = DASH_TIME
	dashing = true
	_dash_cooldown = DASH_COOLDOWN
	dash_cooldown = DASH_COOLDOWN
	velocity.x = direction.x * DASH_SPEED
	velocity.z = direction.z * DASH_SPEED
	return true


func toggle_crouch() -> void:
	crouching = not crouching


func toggle_boost() -> void:
	boosted = not boosted


func _physics_process(delta: float) -> void:
	if field == null or visual == null:
		return
	_damage_cooldown = maxf(0.0, _damage_cooldown - delta)
	if health <= 0:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		move_speed = 0.0
		return
	if _dash_cooldown > 0.0:
		_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
		dash_cooldown = _dash_cooldown
	if _dash_left > 0.0:
		_dash_left = maxf(0.0, _dash_left - delta)
	dashing = _dash_left > 0.0 and grounded
	var stick := Vector2.ZERO
	if joystick != null and joystick.input_enabled:
		stick = joystick.direction
	var desired := 0.0 if _dash_left > 0.0 else _desired_speed(stick)
	if endless_run_active and _dash_left <= 0.0:
		desired = endless_run_speed
	# Auto-run menjaga gait Sprint terus aktif. Mode biasa tetap menurunkan gait
	# seiring laju badan melambat agar langkah dan gerak tetap sinkron.
	if endless_run_active and _dash_left <= 0.0:
		gait = str(GAIT_CLIPS[GAIT_CLIPS.size() - 1])
	else:
		gait = select_gait(maxf(desired, move_speed), gait, stick, velocity)
	var target := _target_velocity(stick, desired)
	if endless_run_active and _dash_left <= 0.0:
		target = _endless_run_velocity(desired, stick)
	var flat := Vector2(velocity.x, velocity.z)
	var blended := flat
	if _dash_left > 0.0:
		# Dorongan dash tidak dikurangi input sampai durasinya habis.
		blended = flat
	elif _airborne:
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


## Kecepatan tertinggi mengikuti kecepatan alami klip lari tercepat (hasil ukur
## tulang kaki), bukan angka tetap. Kalau badan lebih cepat dari yang bisa
## ditandingi klip tercepat, kakinya meluncur dan tes anti-meluncur gagal.
func max_speed() -> float:
	if visual == null:
		return MAX_SPEED
	var natural: float = visual.natural_speed(GAIT_CLIPS[GAIT_CLIPS.size() - 1])
	return maxf(MAX_SPEED * 0.5, natural * 1.5)


func _desired_speed(stick: Vector2) -> float:
	var strength := minf(stick.length(), 1.0)
	if strength < 0.02:
		return 0.0
	var speed := max_speed() * strength * survival_move_speed_multiplier
	if boosted:
		speed *= BOOST_MULTIPLIER
	if crouching:
		speed = minf(speed, CROUCH_SPEED)
	return speed


func _endless_run_velocity(speed: float, stick: Vector2) -> Vector3:
	var forward := Vector3(endless_run_direction.x, 0.0, endless_run_direction.z).normalized()
	if forward.length_squared() < 0.5:
		forward = Vector3(0.0, 0.0, -1.0)
	# Analog kiri/kanan mengarahkan lari; dorongan maju tetap otomatis.
	var right := forward.cross(Vector3.UP).normalized()
	var steer := clampf(stick.x, -1.0, 1.0) * 0.34
	return (forward + right * steer).normalized() * speed


func _target_velocity(stick: Vector2, desired: float) -> Vector3:
	# Badan bergerak secepat yang diminta analog. Dulu laju badan dipaksa ikut
	# kecepatan alami klip (natural x skala yang dipotong di 1,5), jadi klip jalan
	# yang lambat membuat badan lambat juga — analog terasa lemas dan band gait
	# tidak pernah naik ke lari. Sekarang badan yang menentukan; kecepatan main
	# animasi yang disesuaikan supaya kaki tidak meluncur.
	if desired <= 0.02 or field == null or orbit == null:
		return Vector3.ZERO
	return orbit.movement_direction(stick) * desired


func _apply_animation(desired: float) -> void:
	# Di udara, animasi melayang selalu menang: klip tolakan/mendarat yang panjang
	# tidak boleh mengunci badan sampai terlihat berhenti.
	if _airborne:
		if visual.gait != AIR_FALL and _air_time >= JUMP_POSE_TIME:
			visual.set_air_clip(AIR_FALL, 1.0)
		return
	# Klip gait mengikuti laju badan (bukan cuma input tekanan analog): saat
	# meluncur berhenti setelah berlari, kaki tetap mengayun secepat badan.
	#
	# set_locomotion TIDAK menimpa klip aksi sekali jalan (mannequin menyimpan
	# gait-nya saja lalu memutarnya saat aksinya habis), jadi ini aman dipanggil
	# juga saat sedang menyerang. Dulu ada `return` lebih awal ketika is_busy():
	# akibatnya gait tertinggal di nilai SEBELUM aksi, dan begitu aksinya selesai
	# badan memakai gait lama (mis. jalan pelan) selama satu frame selagi masih
	# cepat — kakinya meluncur sesaat, terbaca sebagai patah.
	var reference := maxf(desired, move_speed)
	var scale := 1.0
	if _dash_left > 0.0:
		# Selama dash animasi justru DIPERLAMBAT: satu langkah besar yang selesai
		# menapak tepat ketika dorongan habis. Dibanding kecepatan main normal
		# pada 12 m/s (1,5-2x), ini jauh lebih pelan — itu yang membuat dash
		# terbaca sebagai hentakan, bukan lari cepat biasa.
		scale = DASH_PLAYBACK
	elif reference > 0.05:
		var natural: float = visual.natural_speed(gait)
		var scale_max := RUN_ZONE_MAX_SCALE if endless_run_active else \
			SCALE_MAX_BOOST if boosted else SCALE_MAX
		scale = clampf(reference / natural, SCALE_MIN, scale_max)
	speed_scale = scale
	var animation_gait := "Sword_Idle" if sword_mode and gait == IDLE else gait
	visual.set_locomotion(animation_gait, scale)


## Band kecepatan tiap klip, dihitung dari kecepatan alami yang diukur dari
## tulang kaki. Batas atas tiap band = 1,5x kecepatan alaminya, batas bawah =
## batas atas band sebelumnya. Dengan begitu klip jalan tidak pernah dipaksa
## muter jauh dari 1x (kaki meluncur) dan klip lari tidak dipakai untuk jalan
## pelan (kaki muter kencang tanpa badan bergerak).
func _gait_bands() -> Array:
	if not _bands.is_empty():
		return _bands
	if visual == null:
		return []
	var previous_max := IDLE_EXIT
	for clip in GAIT_CLIPS:
		var natural: float = visual.natural_speed(str(clip))
		var top: float = natural * 1.5
		_bands.append({"clip": str(clip), "min": previous_max, "max": top})
		previous_max = top
	return _bands


func _band_for(speed: float) -> String:
	var bands := _gait_bands()
	if bands.is_empty():
		return IDLE
	for entry in bands:
		if speed >= float(entry["min"]) and speed <= float(entry["max"]):
			return str(entry["clip"])
	# Di bawah band pertama = Idle. Tanpa cabang ini kecepatan nol jatuh ke
	# fallback klip TERCEPAT, jadi pemain yang berhenti berpose lari.
	if speed < float(bands[0]["min"]):
		return IDLE
	return GAIT_CLIPS[GAIT_CLIPS.size() - 1]


func select_gait(speed: float, current: String, stick := Vector2.ZERO,
		body_velocity := Vector3.ZERO) -> String:
	if crouching:
		return CROUCH_WALK if speed > 0.12 else CROUCH_IDLE
	var target := _band_for(speed)
	# Jalan mundur pelan memakai Walk_Formal. Saat analog penuh, band Jog/Sprint
	# menang supaya animasi tidak turun jadi jalan ketika badan sudah berlari.
	# UAL tidak punya klip mundur Jog/Sprint atau strafe kiri/kanan.
	var moving_backward := speed > IDLE_EXIT and _moving_backward(stick, body_velocity)
	if moving_backward and target == GAIT_CLIPS[0]:
		target = BACKWARD_CLIP
	if target == current:
		return current
	# Histeresis menahan klip supaya tidak berkedip di ambang antarband lari.
	# Band Idle TIDAK diperpanjang ke bawah dan band jalan tidak boleh turun
	# sampai nol: kalau boleh, pemain yang sudah berhenti tetap memutar klip
	# jalan — kelihatan seperti jalan di tempat meski badan diam.
	if current == IDLE:
		return current if speed <= IDLE_EXIT else target
	if current == BACKWARD_CLIP:
		return current if target == BACKWARD_CLIP else target
	for entry in _gait_bands():
		if str(entry["clip"]) != current:
			continue
		var low := maxf(float(entry["min"]) - HYSTERESIS, IDLE_EXIT)
		if speed >= low and speed <= float(entry["max"]) + HYSTERESIS:
			return current
	return target


## True kalau pemain bergerak ke belakang relatif hadapan kamera. Dibaca dari
## ARAH ANALOG dulu (bukan laju badan): saat baru mulai bergerak, arah laju masih
## berisik dan klip mundur akan berkedip. Laju badan dipakai sebagai cadangan
## saat analog sudah dilepas tapi badan masih meluncur.
func _moving_backward(stick: Vector2, body_velocity: Vector3) -> bool:
	if orbit == null:
		return false
	var forward := orbit.camera_forward()
	if forward.length() < 0.05:
		return false
	var flat_forward := Vector2(forward.x, forward.z).normalized()
	if stick.length() > 0.15:
		var wish := orbit.movement_direction(stick)
		return Vector2(wish.x, wish.z).normalized().dot(flat_forward) < BACKWARD_DOT
	var move := Vector2(body_velocity.x, body_velocity.z)
	if move.length() < 0.2:
		return false
	return move.normalized().dot(flat_forward) < BACKWARD_DOT


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
	# Batas pantai hanya berlaku di mode pulau; Survival memakai tanah tanpa batas.
	if world_bounds_enabled and field != null and not Field.is_inside(
			global_position.x, global_position.z, SHORE_MARGIN):
		var fixed := Field.clamp_inside(
			Vector2(global_position.x, global_position.z), SHORE_MARGIN)
		global_position.x = fixed.x
		global_position.z = fixed.y
		velocity.x = 0.0
		velocity.z = 0.0
	if global_position.y < FALL_RESET:
		spawn(Vector2.ZERO)
