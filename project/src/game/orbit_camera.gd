extends Node3D
## Kamera dekat, satu jari kanan untuk orbit, dua jari kanan untuk zoom.

const DEFAULT_DISTANCE := 4.0
const MIN_DISTANCE := 2.4
const MAX_DISTANCE := 8.0
const MIN_PITCH := 0.10
const MAX_PITCH := 1.15

var input_enabled := true
var interact_exclusion: Control
var input_exclusion: Control
var attack_exclusion: Control
var speed_exclusion: Control
var character_exclusion: Control
var combat_style_exclusion: Control
var yaw := 0.0
var pitch := 0.30
var distance := DEFAULT_DISTANCE
var arm: SpringArm3D
var camera: Camera3D
var _touches: Dictionary[int, Vector2] = {}


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
			for control in [interact_exclusion, input_exclusion, attack_exclusion,
					speed_exclusion, character_exclusion, combat_style_exclusion]:
				if is_instance_valid(control) and control.is_visible_in_tree():
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


func _apply_orbit() -> void:
	rotation.y = yaw
	arm.rotation.x = -pitch
	arm.spring_length = distance


func movement_direction(stick: Vector2) -> Vector3:
	return Vector3(stick.x, 0.0, stick.y).rotated(Vector3.UP, yaw)
