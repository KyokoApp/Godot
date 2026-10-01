extends Node3D
## Mannequin UAL — satu-satunya karakter. Satu skeleton, dua perpustakaan animasi
## (UAL1 + UAL2 = 85 klip) yang dimuat ke SATU AnimationPlayer, jadi transisi,
## cross-fade, dan lapisan tubuh atas berjalan di clock yang sama.
##
## Perbaikan animasi yang dikerjakan di sini:
##  1. Tidak ada lagi rig bayangan + penyalinan pose tiap frame (dulu UAL2 diputar
##     di model tersembunyi lalu pose-nya disalin manual — lambat dan patah).
##  2. Mode loop tiap klip disetel benar dari katalog (loop vs sekali vs tahan).
##  3. Kecepatan main dicocokkan dengan langkah hasil ukur (tidak meluncur).
##  4. Offset tanah per klip menjaga kaki tidak tenggelam di klip rendah.

signal clip_changed(clip: String)

enum Mode { LOCOMOTION, ACTION, SHOWCASE, HELD }

const MODEL = preload("res://assets/mannequin/UAL1_Standard.glb")
const COMBAT_MODEL = preload("res://assets/combat/UAL2_Standard.glb")
const OUTLINE = preload("res://src/game/character_outline.gdshader")
const CastLayer = preload("res://src/game/animation/cast_layer.gd")
const Catalog = preload("res://src/game/animation/catalog.gd")
const Metrics = preload("res://src/game/animation/anim_metrics.gd")
const IDLE := "Idle_Loop"
const COMBAT_LIBRARY := "ual2"
const FADE := 0.18
const OFFSET_SPEED := 6.0

var animation: AnimationPlayer
var skeleton: Skeleton3D
var cast_layer: CastLayer
var metrics: Dictionary = {}
var mode := Mode.LOCOMOTION
var clip := IDLE
var gait := IDLE
var ground_offset := 0.0
var playback_scale := 1.0
var _hold_after := false
var _action_left := 0.0
var _model: Node3D
var _library: AnimationLibrary


func _ready() -> void:
	var model: Node3D = MODEL.instantiate()
	# Koreksi arah model yang dipakai project lama (menghadap -Z Godot).
	model.rotation.y = PI
	add_child(model)
	_model = model
	animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if animation == null or skeleton == null:
		push_error("Mannequin: AnimationPlayer/Skeleton3D hilang")
		return
	_merge_combat_library()
	_apply_material()
	_configure_clips()
	metrics = Metrics.measure_catalog(animation, skeleton, Catalog)
	animation.play(Catalog.play_name(IDLE), 0.0)
	animation.advance(0.0)
	_setup_cast_layer()
	print("[mannequin] %d klip dimuat, %d metrik terukur" % [
		animation.get_animation_list().size(), metrics.size()])


func _merge_combat_library() -> void:
	# UAL2 punya tulang, rest pose, dan mesh yang sama; pustakanya dipindah ke
	# AnimationPlayer utama supaya semua klip berbagi satu clock animasi.
	var source: Node3D = COMBAT_MODEL.instantiate()
	var source_player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if source_player == null:
		push_error("Mannequin: UAL2 tidak punya AnimationPlayer")
		source.free()
		return
	_library = source_player.get_animation_library("")
	if _library == null:
		push_error("Mannequin: pustaka UAL2 kosong")
		source.free()
		return
	animation.add_animation_library(COMBAT_LIBRARY, _library)
	source.free()


func _apply_material() -> void:
	const MATERIAL := Color(0.68, 0.58, 0.84)
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var material := StandardMaterial3D.new()
		material.albedo_color = MATERIAL
		material.roughness = 0.85
		var outline := ShaderMaterial.new()
		outline.shader = OUTLINE
		material.next_pass = outline
		mesh.material_override = material


func _configure_clips() -> void:
	for entry in Catalog.entries():
		var name: String = entry["name"]
		var play_name: String = Catalog.play_name(name)
		if not animation.has_animation(play_name):
			push_error("Mannequin: klip hilang dari berkas: " + play_name)
			continue
		var source := animation.get_animation(play_name)
		source.loop_mode = Animation.LOOP_LINEAR if Catalog.is_loop(name) \
			else Animation.LOOP_NONE


func _setup_cast_layer() -> void:
	if not animation.has_animation(CastLayer.CLIP):
		push_error("Mannequin: klip casting hilang")
		return
	cast_layer = CastLayer.new()
	cast_layer.name = "UpperBodyCast"
	skeleton.add_child(cast_layer)
	cast_layer.configure(animation.get_animation(CastLayer.CLIP))
	if cast_layer.tracks.is_empty():
		push_error("Mannequin: filter tulang casting kosong")


# ------------------------------------------------------------- lokomosi ----

func natural_speed(name: String) -> float:
	var measured: Dictionary = metrics.get(name, {})
	var speed := float(measured.get("natural_speed", 0.0))
	return speed if speed > 0.05 else 1.0


func set_locomotion(name: String, playback_speed := 1.0) -> void:
	if mode != Mode.LOCOMOTION:
		# Klip pilihan panel atau aksi sekali jalan tidak boleh ditimpa pemain.
		gait = name
		return
	gait = name
	mode = Mode.LOCOMOTION
	if name != clip:
		_play(name, FADE, playback_speed)
	else:
		animation.speed_scale = clampf(playback_speed, 0.1, 3.0)


func set_air_clip(name: String, playback_speed := 1.0) -> void:
	# Klip udara dipilih pemain (lompat), bukan dari band kecepatan.
	mode = Mode.LOCOMOTION
	gait = name
	if name != clip:
		_play(name, 0.1, playback_speed)
	else:
		animation.speed_scale = clampf(playback_speed, 0.1, 3.0)


func play_action(name: String) -> float:
	var measured: Dictionary = metrics.get(name, {})
	var length := float(measured.get("length", 0.0))
	if length <= 0.0 or not animation.has_animation(Catalog.play_name(name)):
		return 0.0
	_hold_after = Catalog.holds_last_frame(name)
	mode = Mode.ACTION
	_action_left = length
	_play(name, FADE, 1.0)
	return length


func play_showcase(name: String) -> void:
	# Dipilih manual dari panel animasi: loop klip loop, tahan klip sekali.
	_hold_after = Catalog.holds_last_frame(name)
	mode = Mode.SHOWCASE if Catalog.is_loop(name) else Mode.ACTION
	_action_left = length_of(name)
	_play(name, FADE, 1.0)


func return_to_locomotion() -> void:
	_hold_after = false
	_action_left = 0.0
	mode = Mode.LOCOMOTION
	_play(gait, 0.24, 1.0)


func freeze_at_last_frame() -> void:
	mode = Mode.HELD
	_hold_after = true


func current_label() -> String:
	return Catalog.label_for(clip)


func length_of(name: String) -> float:
	var measured: Dictionary = metrics.get(name, {})
	return float(measured.get("length", 0.0))


func description_of(name: String) -> String:
	var entry := Catalog.find(name)
	return str(entry.get("desc", "")) if not entry.is_empty() else ""


func set_playback_scale(value: float) -> void:
	playback_scale = clampf(value, 0.1, 2.0)
	# Hanya klip tampilan yang ikut lambat; lokomosi tetap sinkron dengan badan.
	if animation != null and (mode == Mode.ACTION or mode == Mode.SHOWCASE):
		animation.speed_scale = playback_scale


func clip_length() -> float:
	if animation == null:
		return 0.0
	return animation.current_animation_length


func progress() -> float:
	var length := clip_length()
	if length <= 0.0:
		return 0.0
	return clampf(animation.current_animation_position / length, 0.0, 1.0)


func is_busy() -> bool:
	return mode == Mode.ACTION or mode == Mode.SHOWCASE


func start_cast() -> void:
	if cast_layer != null:
		cast_layer.begin()


func _play(name: String, fade: float, playback_speed: float) -> void:
	clip = name
	var scale := playback_speed
	if mode == Mode.ACTION or mode == Mode.SHOWCASE:
		scale *= playback_scale
	animation.speed_scale = clampf(scale, 0.1, 3.0)
	animation.play(Catalog.play_name(name), fade)
	animation.advance(0.0)
	clip_changed.emit(clip)


func _physics_process(delta: float) -> void:
	if animation == null:
		return
	# Timer sendiri, bukan sinyal: deterministik di headless dan tidak bisa
	# terlewat saat klip diganti cepat dari panel.
	if mode == Mode.ACTION and _action_left > 0.0:
		_action_left = maxf(0.0, _action_left - delta * maxf(animation.speed_scale, 0.01))
		if _action_left <= 0.0:
			if _hold_after:
				mode = Mode.HELD
				animation.pause()
			else:
				return_to_locomotion()
	# Offset tanah halus: klip rendah (guling, meluncur) tidak menenggelamkan kaki.
	var measured: Dictionary = metrics.get(clip, {})
	var target := float(measured.get("ground_offset", 0.0))
	ground_offset = lerpf(ground_offset, target, 1.0 - exp(-OFFSET_SPEED * delta))
	_model.position.y = ground_offset


# ----------------------------------------------- kontak kaki untuk efek ----

func foot_pose(left: bool) -> Transform3D:
	var bone := skeleton.find_bone("foot_l" if left else "foot_r")
	if bone < 0:
		return global_transform
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone)


func foot_clearance(left: bool) -> float:
	var bone := skeleton.find_bone("foot_l" if left else "foot_r")
	if bone < 0:
		return 0.1
	var rest := skeleton.get_bone_global_rest(bone)
	return clampf(rest.origin.y, 0.06, 0.18)


func foot_stride_lift(left: bool) -> float:
	var bone := skeleton.find_bone("foot_l" if left else "foot_r")
	if bone < 0:
		return 0.0
	return skeleton.get_bone_global_pose(bone).origin.y \
		- skeleton.get_bone_global_rest(bone).origin.y
