extends Node3D
## Kamera dekat, satu jari kanan untuk orbit, dua jari kanan untuk zoom.

const DEFAULT_DISTANCE := 4.0
const MIN_DISTANCE := 2.4
const MAX_DISTANCE := 8.0
const MIN_PITCH := 0.10
const MAX_PITCH := 1.15

var input_enabled := true
## Kontrol yang menangkap sentuhan lebih dulu (panel, tombol); sentuhan di
## atasnya tidak boleh memutar kamera.
var exclusions: Array[Control] = []
var yaw := 0.0
var pitch := 0.30
var distance := DEFAULT_DISTANCE
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
				distance = clampf(distance * before / after, MIN_DISTANCE, MAX_DISTANCE)
		else:
			var motion := drag.position - previous
			# Sensitivitas mengikuti lebar viewport, bukan kepadatan pixel perangkat.
			var sensitivity := TAU / get_viewport().get_visible_rect().size.x
			yaw = wrapf(yaw - motion.x * sensitivity, -PI, PI)
			pitch = clampf(pitch + motion.y * sensitivity, MIN_PITCH, MAX_PITCH)


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


func movement_direction(stick: Vector2) -> Vector3:
	return Vector3(stick.x, 0.0, stick.y).rotated(Vector3.UP, yaw)
