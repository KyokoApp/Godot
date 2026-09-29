extends Node3D
## Actual ankle/toe poses + floor ray contacts, not a generic ribbon behind the player.

const Character = preload("res://src/game/mannequin.gd")
const MeshFactory = preload("res://src/game/foot_fire/foot_fire_mesh.gd")
const SHADER = preload("res://src/game/foot_fire/foot_fire.gdshader")
const MAX_STAMPS := 16
const LIFETIME := 1.15
const PALETTES := {
	"miku": [Color("9661ef"), Color("479dff"), Color("efffff")],
	"kanna": [Color("fa6e23"), Color("ffd158"), Color("fff6d0")],
	"mannequin": [Color("6228cc"), Color("ad74ff"), Color("b4efff")],
}

var character: Character
var body: CharacterBody3D
var island: Node3D
var emitted := 0
var stamps: Array[MeshInstance3D] = []
var ages: Array[float] = []
var _next := 0
var _contact := [false, false]
var _cooldowns := [0.0, 0.0]
var _previous := Vector3.ZERO
var _skin := ""


func _ready() -> void:
	var mesh := MeshFactory.create()
	for index in range(MAX_STAMPS):
		var stamp := MeshInstance3D.new()
		stamp.mesh = mesh
		stamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stamp.extra_cull_margin = 0.08
		var material := ShaderMaterial.new()
		material.shader = SHADER
		stamp.material_override = material
		add_child(stamp)
		stamp.hide()
		stamps.append(stamp)
		ages.append(LIFETIME)
	if body != null:
		_previous = body.global_position


func _physics_process(delta: float) -> void:
	for index in range(MAX_STAMPS):
		if not stamps[index].visible:
			continue
		ages[index] += delta
		if ages[index] >= LIFETIME:
			stamps[index].hide()
		else:
			var material := stamps[index].material_override as ShaderMaterial
			material.set_shader_parameter("age", ages[index] / LIFETIME)
	for side in range(2):
		_cooldowns[side] = maxf(0, _cooldowns[side] - delta)
	if body == null or character == null or island == null:
		return
	var motion := body.global_position - _previous
	var travel := motion.length()
	_previous = body.global_position
	if travel > 3:
		clear()
		return
	if character.skin_id != _skin:
		_skin = character.skin_id
		_contact = [false, false]
	if not body.is_on_floor() or Vector2(motion.x, motion.z).length() / maxf(delta, 0.001) < 0.25:
		_contact = [false, false]
		return
	for side in range(2):
		_sample(side)


func _sample(side: int) -> void:
	# Retargeted proportions can keep an ankle inside the contact band throughout
	# a stride (Kanna). Use the real mocap foot's lift to re-arm, never a timer alone.
	var lift := character.foot_stride_lift(side == 0)
	if lift > 0.04:
		if lift > 0.075:
			_contact[side] = false
		return
	var pose := character.foot_pose(side == 0)
	var ray := PhysicsRayQueryParameters3D.create(pose.origin + Vector3.UP * 0.22,
		pose.origin - Vector3.UP * 0.85, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		_contact[side] = false
		return
	var point: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var distance := pose.origin.y - point.y
	var clearance := character.foot_clearance(side == 0)
	if distance > clearance + 0.09 or normal.y < 0.6:
		_contact[side] = false
		return
	if distance > clearance + 0.035 or _contact[side] or _cooldowns[side] > 0:
		return
	if not island.is_walkable_shore(point.x, point.z):
		return
	_contact[side] = true
	_cooldowns[side] = 0.18
	var forward := -pose.basis.z
	forward = forward.slide(normal).normalized()
	if forward.length_squared() < 0.5:
		return
	var sole_scale := pose.basis.get_scale().x
	pose.basis = Basis(forward.cross(normal).normalized() * sole_scale, normal,
		-forward * sole_scale)
	pose.origin = point + normal * 0.014 + forward * (0.045 * sole_scale)
	add_stamp(pose, character.skin_id, side == 0)


func add_stamp(pose: Transform3D, skin_id: String, left := false) -> void:
	var stamp := stamps[_next]
	stamp.global_transform = pose
	if left:
		stamp.scale.x *= -1.0
	var colors: Array = PALETTES.get(skin_id, PALETTES["mannequin"])
	var material := stamp.material_override as ShaderMaterial
	material.set_shader_parameter("cool", colors[0])
	material.set_shader_parameter("middle", colors[1])
	material.set_shader_parameter("hot", colors[2])
	material.set_shader_parameter("age", 0.0)
	material.set_shader_parameter("seed", float(emitted % 19))
	ages[_next] = 0
	stamp.show()
	_next = (_next + 1) % MAX_STAMPS
	emitted += 1


func clear() -> void:
	for stamp in stamps:
		stamp.hide()
	_contact = [false, false]
