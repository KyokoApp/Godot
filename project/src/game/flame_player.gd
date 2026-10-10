extends Node3D
## A light, non-physical player represented only by a warm flame.

const Joystick = preload("res://src/game/virtual_joystick.gd")
const Orbit = preload("res://src/game/orbit_camera.gd")
const FireVisual = preload("res://src/game/realistic_fire_visual.gd")

## Leave a clear, readable air gap between the fire avatar and dune silhouettes.
const FLOAT_HEIGHT := 6.0
const EDGE_MARGIN := 1.3
const ACCELERATION := 18.0
const BRAKING := 22.0
const FALLBACK_LIMIT := 500.0

var max_speed := 5.0
var move_speed := 0.0
var field: Node3D
var joystick: Joystick
var orbit: Orbit

var _velocity := Vector3.ZERO
var _fire: FireVisual


func _ready() -> void:
	name = "Player"
	_fire = FireVisual.new()
	_fire.name = "FireVisual"
	add_child(_fire)


func spawn(point: Vector2) -> void:
	var safe_point := _clamp_inside(point, EDGE_MARGIN)
	var ground := _surface_height(safe_point.x, safe_point.y)
	global_position = Vector3(safe_point.x, ground + FLOAT_HEIGHT, safe_point.y)
	_velocity = Vector3.ZERO
	move_speed = 0.0


func set_view_camera(camera: Camera3D) -> void:
	if _fire != null:
		_fire.look_camera = camera


func ground_position() -> Vector3:
	return global_position - Vector3(0.0, FLOAT_HEIGHT, 0.0)


func _physics_process(delta: float) -> void:
	var input_direction := _read_input()
	var desired_velocity := Vector3.ZERO
	if input_direction.length_squared() > 0.0001:
		var direction := Vector3(input_direction.x, 0.0, input_direction.y)
		if orbit != null:
			direction = orbit.movement_direction(input_direction)
		desired_velocity = direction * max_speed
	var response := ACCELERATION if desired_velocity.length_squared() > 0.0001 else BRAKING
	_velocity = _velocity.move_toward(desired_velocity, response * delta)
	move_speed = Vector2(_velocity.x, _velocity.z).length()

	var next_position := global_position + _velocity * delta
	var safe_point := _clamp_inside(Vector2(next_position.x, next_position.z), EDGE_MARGIN)
	next_position.x = safe_point.x
	next_position.z = safe_point.y
	var target_height := _surface_height(safe_point.x, safe_point.y) + FLOAT_HEIGHT
	if target_height > global_position.y:
		# Rise with the sampled mesh so the flame never lags inside an uphill dune.
		next_position.y = target_height
	else:
		# Ease down over a descent to avoid a visibly dropping flame.
		next_position.y = lerpf(global_position.y, target_height, 1.0 - exp(-12.0 * delta))
	global_position = next_position
	_fire.external_velocity = _velocity


func _clamp_inside(point: Vector2, margin: float) -> Vector2:
	if field != null and field.has_method("clamp_inside"):
		return field.call("clamp_inside", point, margin)
	var limit := FALLBACK_LIMIT - maxf(margin, 0.0)
	return Vector2(clampf(point.x, -limit, limit), clampf(point.y, -limit, limit))


func _read_input() -> Vector2:
	if joystick != null and joystick.input_enabled:
		if joystick.direction.length_squared() > 0.0001:
			return joystick.direction.limit_length(1.0)
	var keyboard := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		keyboard.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		keyboard.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		keyboard.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		keyboard.y += 1.0
	if not keyboard.is_zero_approx():
		return keyboard.limit_length(1.0)
	return Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down", 0.16)


func _surface_height(x: float, z: float) -> float:
	if field != null and field.has_method("surface_height"):
		return float(field.call("surface_height", x, z))
	return 0.0
