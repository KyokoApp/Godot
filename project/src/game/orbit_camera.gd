extends Node3D
## Kamera dekat, satu jari kanan untuk orbit, dua jari kanan untuk zoom.

const DEFAULT_DISTANCE := 4.0
## Bisa dizoom sampai benar-benar menempel (0,35 m dari titik pandang di kepala).
## Titik pandang ada di setinggi kepala, jadi pada jarak ini yang tampak hanya
## sebagian wajah/rambut — bukan lagi seluruh badan seperti batas 2,4 m dulu.
const MIN_DISTANCE := 0.35
## Dunia kembali 100 m: 62 m cukup untuk melihat sebagian besar pulau tanpa
## menjauh berlebihan dari karakter.
const MAX_DISTANCE := 62.0
## Cukup panjang untuk zoom keluar di pulau kecil tanpa menembus bukit jauh.
const ARM_COLLISION_LIMIT := 30.0
## Zoom roda tetikus untuk main di desktop/editor (di HP tetap cubit dua jari).
const WHEEL_STEP := 1.15
const MIN_PITCH := 0.10
const MAX_PITCH := 1.15
const SURVIVAL_TOP_DOWN_MIN_PITCH := 1.18
const SURVIVAL_TOP_DOWN_PITCH := 1.28
const SURVIVAL_TOP_DOWN_MAX_PITCH := 1.38
const SURVIVAL_TOP_DOWN_DISTANCE := 17.0

var input_enabled := true
## Kontrol yang menangkap sentuhan lebih dulu (panel, tombol); sentuhan di
## atasnya tidak boleh memutar kamera.
var exclusions: Array[Control] = []
var yaw := 0.0
var pitch := 0.30
var pitch_min := MIN_PITCH
var pitch_max := MAX_PITCH
var distance := DEFAULT_DISTANCE
var zoom_enabled := true
## Titik bidik kamera relatif ke pemain. Dulu angka 0,55 ini ditulis di main.gd;
## sekarang jadi properti supaya tes render bisa membidik leher atau kain tanpa
## mengubah perilaku permainan (nilainya tidak pernah diubah selain tes).
var focus_offset := Vector3(0.0, 0.55, 0.0)
var arm: SpringArm3D
var camera: Camera3D
var _touches: Dictionary[int, Vector2] = {}
var _shake_duration := 0.0
var _shake_total := 0.0
var _shake_intensity := 0.0
var _shake_phase := 0.0


func _ready() -> void:
	arm = SpringArm3D.new()
	arm.collision_mask = 1
	arm.margin = 0.18
	var sphere := SphereShape3D.new()
	sphere.radius = 0.20
	arm.shape = sphere
	add_child(arm)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 65.0
	camera.near = 0.1
	arm.add_child(camera)
	get_viewport().size_changed.connect(reset_touches)
	_apply_orbit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		reset_touches()


func reset_touches() -> void:
	_touches.clear()


func capture_state() -> Dictionary:
	return {
		"yaw": yaw,
		"pitch": pitch,
		"pitch_min": pitch_min,
		"pitch_max": pitch_max,
		"distance": distance,
		"zoom_enabled": zoom_enabled,
		"focus_offset": focus_offset,
	}


func restore_state(state: Dictionary) -> void:
	pitch_min = float(state.get("pitch_min", MIN_PITCH))
	pitch_max = float(state.get("pitch_max", MAX_PITCH))
	yaw = float(state.get("yaw", 0.0))
	pitch = float(state.get("pitch", 0.30))
	distance = float(state.get("distance", DEFAULT_DISTANCE))
	zoom_enabled = bool(state.get("zoom_enabled", true))
	var restored_focus: Vector3 = state.get(
		"focus_offset", Vector3(0.0, 0.55, 0.0))
	focus_offset = restored_focus
	reset_touches()


func set_top_down_mode() -> void:
	pitch_min = SURVIVAL_TOP_DOWN_MIN_PITCH
	pitch_max = SURVIVAL_TOP_DOWN_MAX_PITCH
	pitch = SURVIVAL_TOP_DOWN_PITCH
	distance = SURVIVAL_TOP_DOWN_DISTANCE
	zoom_enabled = false


func _input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed or touch.canceled:
			_touches.erase(touch.index)
		elif touch.position.x >= get_viewport().get_visible_rect().size.x * 0.5:
			for control in exclusions:
				if not is_instance_valid(control) or not control.is_visible_in_tree():
					continue
				if control.get_global_rect().has_point(touch.position):
					return
			if _touches.size() < 2:
				_touches[touch.index] = touch.position
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not button.pressed:
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(1.0 / WHEEL_STEP)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(WHEEL_STEP)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not _touches.has(drag.index):
			return
		var previous: Vector2 = _touches[drag.index]
		var before := _pinch_length()
		_touches[drag.index] = drag.position
		if _touches.size() == 2:
			var after := _pinch_length()
			if before > 8.0 and after > 8.0:
				zoom_by(before / after)
		else:
			var motion := drag.position - previous
			# Sensitivitas mengikuti lebar viewport, bukan kepadatan pixel perangkat.
			var sensitivity := TAU / get_viewport().get_visible_rect().size.x
			yaw = wrapf(yaw - motion.x * sensitivity, -PI, PI)
			pitch = clampf(pitch + motion.y * sensitivity, pitch_min, pitch_max)


## Ubah jarak kamera dengan faktor: < 1 mendekat, > 1 menjauh. Satu tempat
## untuk semua masukan (cubit, roda tetikus, dan tes) supaya batasnya konsisten.
func zoom_by(factor: float) -> void:
	if not zoom_enabled:
		return
	distance = clampf(distance * factor, MIN_DISTANCE, MAX_DISTANCE)


func _pinch_length() -> float:
	if _touches.size() != 2:
		return 0.0
	var points: Array[Vector2] = _touches.values()
	return points[0].distance_to(points[1])


func follow(target: Vector3, delta: float) -> void:
	global_position = global_position.lerp(target, 1.0 - exp(-18.0 * delta))
	_apply_orbit()
	_update_combat_shake(delta)


func combat_shake(intensity: float, duration: float = 0.14) -> void:
	_shake_intensity = clampf(_shake_intensity + intensity, 0.0, 0.18)
	_shake_duration = maxf(_shake_duration, duration)
	_shake_total = maxf(_shake_total, _shake_duration)


func _update_combat_shake(delta: float) -> void:
	if camera == null:
		return
	_shake_duration = maxf(0.0, _shake_duration - delta)
	if _shake_duration <= 0.0:
		camera.position = Vector3.ZERO
		_shake_intensity = 0.0
		_shake_total = 0.0
		return
	_shake_phase += delta * 47.0
	var fade := pow(_shake_duration / maxf(_shake_total, 0.001), 1.6)
	var offset := Vector3(sin(_shake_phase), cos(_shake_phase * 1.31), 0.0)
	camera.position = offset * (_shake_intensity * fade)


func _apply_orbit() -> void:
	rotation.y = yaw
	arm.rotation.x = -pitch
	arm.spring_length = distance
	# Zoom dekat: jangan tembus tanah/wajah. Zoom jauh: tabrakan dimatikan lewat
	# mask 0 (SpringArm3D tidak punya sakelar collide_with_bodies), kalau tidak
	# kamera terjepit di bukit pertama dan pulau tak pernah terlihat.
	arm.collision_mask = 1 if distance < ARM_COLLISION_LIMIT else 0
	if camera != null:
		# Bidang dekat mengikuti jarak: pada 0,1 m jarak tetap, kamera yang sudah
		# menempel masih memotong wajah/rambut. Saat menjauh, angka kecil justru
		# membuat z-fighting di kejauhan, jadi nilainya dibatasi 0,03-0,1.
		camera.near = clampf(distance * 0.15, 0.03, 0.1)


func movement_direction(stick: Vector2) -> Vector3:
	return Vector3(stick.x, 0.0, stick.y).rotated(Vector3.UP, yaw)


## Arah hadap kamera diratakan ke tanah (tanpa komponen y). Kamera berdiri di
## (sin yaw, 0, cos yaw) dari fokus dan melihat ke arah sebaliknya, jadi hadap
## kamera = -(sin yaw, 0, cos yaw). Dipakai pemain untuk membedakan jalan depan
## dan jalan mundur.
func camera_forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))
