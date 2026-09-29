extends Node3D
## Model dan mocap asli dari arsip project, tanpa sistem combat/skin lama.

signal skin_changed(skin_id: String)

const HairSpring = preload("res://src/game/animation/hair_spring.gd")
const KannaRig = preload("res://src/game/animation/kanna_rig.gd")
const MikuRig = preload("res://src/game/animation/miku_rig.gd")
const KANNA := "kanna"
const Retarget = preload("res://src/game/animation/skin_retarget.gd")
const MikuVisual = preload("res://src/game/animation/miku_visual.gd")
const MANNEQUIN := "mannequin"
const MIKU := "miku"
const CastLayer = preload("res://src/game/animation/cast_layer.gd")
const MODEL = preload("res://assets/mannequin/UAL1_Standard.glb")
const OUTLINE = preload("res://src/game/character_outline.gdshader")
const IDLE := "Idle"
const WALK := "Walk"
const RUN := "Jog_Fwd"
const RUN_ON := 2.8
const RUN_OFF := 2.4

var hair: HairSpring
var skin_id := MANNEQUIN
var skin: Node3D
var retarget: Retarget
var source_skeleton: Skeleton3D
var cast_layer: CastLayer
var animation: AnimationPlayer
var state := IDLE
var _skins: Dictionary[String, Node3D] = {}
var _retargets: Dictionary[String, Retarget] = {}
var _source_meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	var model: Node3D = MODEL.instantiate()
	# Koreksi arah model yang digunakan pada mannequin project lama.
	model.rotation.y = PI
	add_child(model)
	animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		_source_meshes.append(mesh)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.68, 0.58, 0.84)
		material.roughness = 0.85
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE
		material.next_pass = outline
		mesh.material_override = material
	if animation == null:
		push_error("Mannequin: AnimationPlayer hilang")
		return
	for clip in [IDLE, WALK, RUN]:
		if not animation.has_animation(clip):
			push_error("Mannequin: klip hilang: " + clip)
			return
		animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	animation.play(IDLE)
	animation.advance(0)
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null or not animation.has_animation(CastLayer.CLIP):
		push_error("Mannequin: rig/klip casting hilang")
		return
	source_skeleton = skeleton
	cast_layer = CastLayer.new()
	cast_layer.name = "UpperBodyCast"
	skeleton.add_child(cast_layer)
	cast_layer.configure(animation.get_animation(CastLayer.CLIP))
	if cast_layer.tracks.is_empty():
		push_error("Mannequin: filter tulang casting kosong")


func update_motion(speed: float) -> void:
	if animation == null:
		return
	var next := WALK
	if speed < 0.05:
		next = IDLE
	elif speed >= RUN_ON or (state == RUN and speed >= RUN_OFF):
		next = RUN
	if next != state:
		state = next
		animation.play(state, 0.18)
	match state:
		WALK:
			animation.speed_scale = clampf(speed / 1.8, 0.25, 1.5)
		RUN:
			animation.speed_scale = clampf(speed / 4.0, 0.6, 1.3)
		_:
			animation.speed_scale = 1.0


func start_cast() -> void:
	if cast_layer != null:
		cast_layer.begin()


func set_skin(selected: String) -> bool:
	if selected not in [MANNEQUIN, MIKU, KANNA] or source_skeleton == null:
		return false
	if selected == skin_id:
		return true
	if selected != MANNEQUIN and not _skins.has(selected):
		if not _load_skin(selected):
			return false
	for mesh in _source_meshes:
		mesh.visible = selected == MANNEQUIN
	for id: String in _skins:
		_skins[id].visible = selected == id
		_retargets[id].active = selected == id
	if selected != MANNEQUIN:
		skin = _skins[selected]
		retarget = _retargets[selected]
		retarget.transfer()
	if hair != null:
		hair.reset_motion()
		hair.active = selected == MIKU
	skin_id = selected
	skin_changed.emit(skin_id)
	return true


func _load_skin(selected: String) -> bool:
	var model := MikuVisual.create(self, source_skeleton, selected == KANNA)
	if model == null:
		return false
	var driver := Retarget.new()
	driver.name = "FinalPoseRetarget_" + selected
	# Every retarget reads after CastLayer; only the selected driver stays active.
	source_skeleton.add_child(driver)
	var destination := model.find_child("Skeleton3D", true, false) as Skeleton3D
	var mapping: Array = KannaRig.PAIRS if selected == KANNA else MikuRig.PAIRS
	if not driver.configure(destination, mapping):
		driver.queue_free()
		model.queue_free()
		return false
	if selected == MIKU:
		hair = HairSpring.new()
		hair.name = "MikuHairSpring"
		destination.add_child(hair)
		hair.configure()
	_skins[selected] = model
	_retargets[selected] = driver
	return true


func foot_pose(left: bool) -> Transform3D:
	var skeleton := source_skeleton if skin_id == MANNEQUIN else retarget.target
	var ankle := "foot_l" if left else "foot_r"
	var toe := "ball_l" if left else "ball_r"
	if skin_id == MIKU:
		ankle = "J_Bip_L_Foot" if left else "J_Bip_R_Foot"
		toe = "J_Bip_L_ToeBase" if left else "J_Bip_R_ToeBase"
	elif skin_id == KANNA:
		ankle = "DEF-Left ankle" if left else "DEF-Right ankle"
		toe = "DEF-Left toe" if left else "DEF-Right toe"
	var bone := skeleton.find_bone(ankle)
	var pose := skeleton.global_transform * skeleton.get_bone_global_pose(bone)
	var tip := skeleton.find_bone(toe)
	var forward := -global_basis.z
	var sole_scale := 1.0
	if tip >= 0:
		var end := skeleton.global_transform * skeleton.get_bone_global_pose(tip)
		forward = end.origin - pose.origin
		sole_scale = clampf(forward.length() * 1.65 + 0.035, 0.20, 0.34) / 0.275
	forward.y = 0
	if forward.length_squared() > 0.00001:
		forward = forward.normalized()
		pose.basis = Basis(forward.cross(Vector3.UP) * sole_scale, Vector3.UP,
			-forward * sole_scale)
	return pose


func foot_clearance(left: bool) -> float:
	var skeleton := source_skeleton if skin_id == MANNEQUIN else retarget.target
	var name := "foot_l" if left else "foot_r"
	if skin_id == MIKU:
		name = "J_Bip_L_Foot" if left else "J_Bip_R_Foot"
	elif skin_id == KANNA:
		name = "DEF-Left ankle" if left else "DEF-Right ankle"
	var rest := skeleton.get_bone_global_rest(skeleton.find_bone(name))
	return clampf(rest.origin.y * skeleton.global_basis.get_scale().y, 0.06, 0.18)


func foot_stride_lift(left: bool) -> float:
	# Mocap swing must re-arm contact even when a shorter retargeted leg remains
	# close to the floor throughout its cycle. Final placement still uses its own foot.
	var bone := source_skeleton.find_bone("foot_l" if left else "foot_r")
	return source_skeleton.get_bone_global_pose(bone).origin.y \
		- source_skeleton.get_bone_global_rest(bone).origin.y
