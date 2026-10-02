extends Node3D
## Actual ankle/toe poses + floor ray contacts, not a generic ribbon behind the player.

const Character = preload("res://src/game/character/aurelia_visual.gd")
const Field = preload("res://src/game/world/field.gd")
const MeshFactory = preload("res://src/game/foot_fire/foot_fire_mesh.gd")
const SHADER = preload("res://src/game/foot_fire/foot_fire.gdshader")
const MAX_STAMPS := 16
const LIFETIME := 1.15
## Tapak api mannequin: inti ungu, tengah lavender, ujung sian.
const PALETTE := [Color("6228cc"), Color("ad74ff"), Color("b4efff")]

var character: Character
var body: CharacterBody3D
var field: Field
var emitted := 0
var stamps: Array[MeshInstance3D] = []
var ages: Array[float] = []
var _next := 0
var _contact := [false, false]
var _cooldowns := [0.0, 0.0]
var _previous := Vector3.ZERO


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
	if body == null or character == null or field == null:
		return
	var motion := body.global_position - _previous
	var travel := motion.length()
	_previous = body.global_position
	if travel > 3:
		clear()
		return
	if not body.is_on_floor() or Vector2(motion.x, motion.z).length() / maxf(delta, 0.001) < 0.25:
		_contact = [false, false]
		return
	for side in range(2):
		_sample(side)


func _sample(side: int) -> void:
	# Fase tumpuan dinilai terhadap ukuran telapak KARAKTER, bukan angka tetap:
	# avatar FBX (kaki 4 % lebih pendek, tulang pergelangan 3 cm lebih dekat ke
	# telapak) berhenti 4 cm lebih tinggi daripada mannequin UAL saat menapak,
	# sehingga ambang 0.04 yang disetel untuk mannequin tidak pernah tercapai.
	# Penempatan tapak tetap dari kaki yang menyentuh, bukan pengatur waktu.
	var clearance := character.foot_clearance(side == 0)
	var band := maxf(clearance, 0.04) + 0.03
	var lift := character.foot_stride_lift(side == 0)
	if lift > band:
		if lift > band * 1.6:
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
	# Tidak ada foot IK: pose stance mocap diproyeksikan ke permukaan padang.
	# Ambang jarak juga diukur dari tebal telapak karakter.
	var margin := maxf(clearance * 0.9, 0.055)
	if distance > clearance + margin + 0.055 or normal.y < 0.6:
		_contact[side] = false
		return
	if distance > clearance + margin or _contact[side] or _cooldowns[side] > 0:
		return
	if not field.is_inside(point.x, point.z, 0.4):
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
	add_stamp(pose, side == 0)


func add_stamp(pose: Transform3D, left := false) -> void:
	var stamp := stamps[_next]
	stamp.global_transform = pose
	if left:
		stamp.scale.x *= -1.0
	var material := stamp.material_override as ShaderMaterial
	material.set_shader_parameter("cool", PALETTE[0])
	material.set_shader_parameter("middle", PALETTE[1])
	material.set_shader_parameter("hot", PALETTE[2])
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
