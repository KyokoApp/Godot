extends Node3D
## Tanah datar tanpa batas fisika; lempeng visual besar mengikuti pemain di dunia Survival.

const GROUND_SHADER = preload("res://src/game/world/survival_ground.gdshader")
const MEADOW = preload("res://assets/nature/meadow_cover.png")
const VISUAL_SIZE := 1024.0
const RECENTER_STEP := 256.0

var player: Node3D
var ground_visual: MeshInstance3D
var _center := Vector2i(99999, 99999)


func _ready() -> void:
	name = "SurvivalField"
	_build_ground_visual()
	_build_infinite_collider()


func surface_height(_x: float, _z: float) -> float:
	return 0.0


func can_grow(_x: float, _z: float) -> bool:
	return true


func allows_foot_effect(_point: Vector3, _margin := 0.0) -> bool:
	return true


func set_grass_cover(_enabled: bool) -> void:
	pass


func _build_ground_visual() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(VISUAL_SIZE, VISUAL_SIZE)
	ground_visual = MeshInstance3D.new()
	ground_visual.name = "EndlessGround"
	ground_visual.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("meadow_cover", MEADOW)
	ground_visual.material_override = material
	ground_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground_visual)


func _build_infinite_collider() -> void:
	var body := StaticBody3D.new()
	body.name = "InfiniteGroundCollider"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.name = "InfinitePlane"
	var plane := WorldBoundaryShape3D.new()
	plane.plane = Plane(Vector3.UP, 0.0)
	shape.shape = plane
	body.add_child(shape)
	add_child(body)


func _process(_delta: float) -> void:
	if player == null or ground_visual == null:
		return
	var center := Vector2i(
			floori(player.global_position.x / RECENTER_STEP),
			floori(player.global_position.z / RECENTER_STEP))
	if center == _center:
		return
	_center = center
	ground_visual.global_position = Vector3(
			float(center.x) * RECENTER_STEP, 0.0, float(center.y) * RECENTER_STEP)
