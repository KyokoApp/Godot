extends Node3D
## Analog-controlled blue light orb that can settle on the grass or transform into flight.

signal form_changed(is_flying: bool)

const Joystick = preload("res://src/game/virtual_joystick.gd")
const Orbit = preload("res://src/game/orbit_camera.gd")
const LightVisual = preload("res://src/game/blue_light_visual.gd")
const HoverShadowShader = preload("res://src/game/hover_shadow.gdshader")

const ORB_RADIUS := 0.24
const GROUNDED_CENTER_HEIGHT := 0.27
const FLYING_CENTER_HEIGHT := 1.48
const FLIGHT_BOB_AMPLITUDE := 0.045
const FLIGHT_BOB_SPEED := 2.3
const TRANSFORM_DURATION := 0.95
const EDGE_MARGIN := 1.3
const ACCELERATION := 18.0
const BRAKING := 22.0
const FALLBACK_LIMIT := 500.0

var max_speed := 5.0
var move_speed := 0.0
var field: Node3D
var joystick: Joystick
var orbit: Orbit
var is_flying := false
var flight_blend := 0.0

var _velocity := Vector3.ZERO
var _light_visual: LightVisual
var _hover_shadow: MeshInstance3D
var _shadow_material: ShaderMaterial
var _transition_start := 0.0
var _transition_target := 0.0
var _transition_elapsed := TRANSFORM_DURATION
var _time := 0.0


func _ready() -> void:
	name = "Player"
	_light_visual = LightVisual.new()
	add_child(_light_visual)
	_build_hover_shadow()


func _build_hover_shadow() -> void:
	_shadow_material = ShaderMaterial.new()
	_shadow_material.shader = HoverShadowShader
	_shadow_material.set_shader_parameter("flight_blend", flight_blend)
	var plane := PlaneMesh.new()
	plane.orientation = PlaneMesh.FACE_Y
	plane.size = Vector2(0.92, 0.68)
	_hover_shadow = MeshInstance3D.new()
	_hover_shadow.name = "HoverShadow"
	_hover_shadow.mesh = plane
	_hover_shadow.material_override = _shadow_material
	_hover_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_hover_shadow)


func _update_hover_shadow() -> void:
	if _hover_shadow == null:
		return
	var ground := _surface_height(global_position.x, global_position.z)
	_hover_shadow.position.y = ground - global_position.y + 0.025
	_shadow_material.set_shader_parameter("flight_blend", flight_blend)


func spawn(point: Vector2) -> void:
	var safe_point := _clamp_inside(point, EDGE_MARGIN)
	var ground := _surface_height(safe_point.x, safe_point.y)
	global_position = Vector3(safe_point.x, ground + _center_height(), safe_point.y)
	_velocity = Vector3.ZERO
	move_speed = 0.0
	_update_hover_shadow()


func set_flying(enabled: bool, instant: bool = false) -> void:
	if enabled == is_flying and not instant:
		return
	is_flying = enabled
	_transition_start = flight_blend
	_transition_target = 1.0 if is_flying else 0.0
	_transition_elapsed = 0.0
	if instant:
		flight_blend = _transition_target
		_transition_start = flight_blend
		_transition_elapsed = TRANSFORM_DURATION
		if is_inside_tree():
			var ground := _surface_height(global_position.x, global_position.z)
			global_position.y = ground + _center_height()
			_update_hover_shadow()
	_update_visual_form()
	form_changed.emit(is_flying)


func toggle_flight() -> void:
	set_flying(not is_flying)


func ground_position() -> Vector3:
	return Vector3(global_position.x,
		_surface_height(global_position.x, global_position.z), global_position.z)


func _physics_process(delta: float) -> void:
	_time += delta
	_advance_transform(delta)
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
	var ground := _surface_height(safe_point.x, safe_point.y)
	var bob := sin(_time * FLIGHT_BOB_SPEED) * FLIGHT_BOB_AMPLITUDE * flight_blend
	var target_y := ground + maxf(ORB_RADIUS + 0.02, _center_height() + bob)
	if target_y >= global_position.y:
		# Follow steep rises immediately, never letting the orb clip into the island.
		next_position.y = target_y
	else:
		# Ease down over a descent; the transformation itself has its own smooth curve.
		next_position.y = lerpf(global_position.y, target_y, 1.0 - exp(-14.0 * delta))
	global_position = next_position
	_update_hover_shadow()
	_light_visual.motion_strength = clampf(move_speed / maxf(max_speed, 0.001), 0.0, 1.0)
	_update_visual_form()


func _advance_transform(delta: float) -> void:
	if is_equal_approx(flight_blend, _transition_target):
		return
	_transition_elapsed = minf(_transition_elapsed + delta, TRANSFORM_DURATION)
	var amount := clampf(_transition_elapsed / TRANSFORM_DURATION, 0.0, 1.0)
	var eased := amount * amount * (3.0 - 2.0 * amount)
	flight_blend = lerpf(_transition_start, _transition_target, eased)


func _center_height() -> float:
	return lerpf(GROUNDED_CENTER_HEIGHT, FLYING_CENTER_HEIGHT, flight_blend)


func _update_visual_form() -> void:
	if _light_visual != null:
		_light_visual.flight_blend = flight_blend


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
