extends Node3D
## Model dan mocap asli dari arsip project, tanpa sistem combat/skin lama.

const Robe = preload("res://src/game/flame_robe.gd")
const MODEL = preload("res://assets/mannequin/UAL1_Standard.glb")
const OUTLINE = preload("res://src/game/character_outline.gdshader")
const IDLE := "Idle"
const WALK := "Walk"
const RUN := "Jog_Fwd"
const RUN_ON := 2.8
const RUN_OFF := 2.4

var terrain: Node3D
var robe: Robe
var animation: AnimationPlayer
var state := IDLE


func _ready() -> void:
	var model: Node3D = MODEL.instantiate()
	# Koreksi arah model yang digunakan pada mannequin project lama.
	model.rotation.y = PI
	add_child(model)
	animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
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
	animation.advance(0.0)
	robe = Robe.new()
	robe.skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	robe.terrain = terrain
	add_child(robe)
	if robe.ready_to_wear:
		# Rig/mocap tetap berjalan; mesh di bawah kain disembunyikan untuk mencegah clipping.
		for node in model.find_children("*", "MeshInstance3D", true, false):
			(node as MeshInstance3D).visible = false


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
