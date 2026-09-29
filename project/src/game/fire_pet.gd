extends Node3D
## Pet adalah node dunia terpisah dari rig. Attack diarahkan ke titik bidik kamera.

const Visual = preload("res://src/game/fire_visual.gd")
const Projectile = preload("res://src/game/fire_projectile.gd")
const Burst = preload("res://src/game/fire_burst.gd")
const COOLDOWN := 0.85
const MAX_PROJECTILES := 3
const MAX_BURSTS := 2

var player: Node3D
var facing: Node3D
var camera: Camera3D
var cooldown := 0.0
var projectiles: Array[CharacterBody3D] = []
var bursts: Array[Node3D] = []
var _body: Node3D
var _time := 0.0


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	_body.add_child(Visual.make_orb(0.30))
	var crown := Visual.make_orb(0.16)
	crown.position = Vector3(-0.08, 0.28, 0)
	crown.scale.y = 0.30
	_body.add_child(crown)
	var eye_material := StandardMaterial3D.new()
	eye_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_material.albedo_color = Color("d9f5ff")
	for side in [-1, 1]:
		var eye := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.045
		sphere.height = 0.11
		sphere.radial_segments = 8
		sphere.rings = 4
		eye.mesh = sphere
		eye.material_override = eye_material
		eye.position = Vector3(side * 0.10, 0.05, -0.27)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_body.add_child(eye)
	if player != null:
		global_position = _desired_position()


func _desired_position() -> Vector3:
	var side := Vector3(1.12, 0, 0.12)
	if facing != null:
		side = facing.global_basis * side
	return player.global_position + side + Vector3(0, 0.55 + sin(_time * 2.4) * 0.09, 0)


func _physics_process(delta: float) -> void:
	_time += delta
	cooldown = maxf(0.0, cooldown - delta)
	if player == null:
		return
	var target := _desired_position()
	if global_position.distance_to(target) > 5:
		global_position = target
	else:
		global_position = global_position.lerp(target, 1.0 - exp(-9.0 * delta))
	# Tetap terpisah dari tubuh, termasuk saat pemain berputar mendadak.
	var offset := Vector2(global_position.x - player.global_position.x,
		global_position.z - player.global_position.z)
	if offset.length() < 0.85:
		var direction := offset.normalized() if offset.length() > 0.001 else Vector2.RIGHT
		global_position.x = player.global_position.x + direction.x * 0.85
		global_position.z = player.global_position.z + direction.y * 0.85
	if facing != null:
		_body.rotation.y = lerp_angle(_body.rotation.y, facing.global_rotation.y, 1.0 - exp(-8 * delta))
	_body.scale = Vector3.ONE * (1.0 + sin(_time * 3.0) * 0.035)


func attack() -> bool:
	_prune()
	if cooldown > 0.0 or projectiles.size() >= MAX_PROJECTILES or camera == null:
		return false
	cooldown = COOLDOWN
	var screen := camera.get_viewport().get_visible_rect().size * Vector2(0.5, 0.42)
	var start := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	var aim := start + direction * 35.0
	var query := PhysicsRayQueryParameters3D.create(start, aim, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		aim = hit["position"]
	var shot := Projectile.new()
	shot.position = global_position
	# Parent game berada pada origin dunia; set global sesudah add agar tetap aman.
	get_parent().add_child(shot)
	shot.global_position = global_position
	var duration := clampf(global_position.distance_to(aim) / 18.0, 0.25, 1.5)
	shot.velocity = (aim - shot.global_position) / duration - Projectile.GRAVITY * duration * 0.5
	shot.impacted.connect(_on_impact)
	projectiles.append(shot)
	return true


func _on_impact(point: Vector3, normal: Vector3) -> void:
	_prune()
	if bursts.size() >= MAX_BURSTS:
		bursts.pop_front().queue_free()
	var burst := Burst.new()
	get_parent().add_child(burst)
	burst.global_position = point + normal * 0.8
	bursts.append(burst)


func _prune() -> void:
	for index in range(projectiles.size() - 1, -1, -1):
		if not is_instance_valid(projectiles[index]):
			projectiles.remove_at(index)
	for index in range(bursts.size() - 1, -1, -1):
		if not is_instance_valid(bursts[index]):
			bursts.remove_at(index)
