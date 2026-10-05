extends Node3D
## Satu mode endless-run: intro singkat penyihir terbang, lalu auto-run maju.
## Lajunya naik bertahap sampai batas playback Sprint agar gait tetap rapat.

signal intro_finished
signal run_started
signal progress_changed(elapsed_seconds: float, speed: float)

const SurvivalField = preload("res://src/game/world/survival_field.gd")
const Player = preload("res://src/game/player.gd")
const Character = preload("res://src/game/mannequin.gd")

const INTRO_DURATION := 2.0
const SPELL_LAUNCH_TIME := 0.52
const SPELL_TRAVEL_TIME := 0.58
const BASE_RUN_SPEED := 3.8
const RUN_ACCELERATION := 0.12
const RUN_SPEED_EXTRA := 0.9
const FORWARD := Vector3(0.0, 0.0, -1.0)

var player: Player
var ground: SurvivalField
var caster: Node3D
var caster_visual: Character
var spell_orb: MeshInstance3D
var phase := "intro"
var elapsed_seconds := 0.0
var current_speed := 0.0
var starting_speed := BASE_RUN_SPEED
var maximum_speed := BASE_RUN_SPEED + RUN_SPEED_EXTRA
var _intro_elapsed := 0.0
var _publish_left := 0.0
var _clock := 0.0
var _spell_launched := false
var _intro_signal_sent := false
var _spell_tween: Tween


func _ready() -> void:
	name = "RunZoneWorld"
	ground = SurvivalField.new()
	ground.name = "RunZoneGround"
	ground.player = player
	add_child(ground)
	if player != null and player.visual != null:
		var sprint_speed := player.visual.natural_speed("Sprint_Loop")
		var animation_limit := sprint_speed * Player.RUN_ZONE_MAX_SCALE
		starting_speed = minf(maxf(BASE_RUN_SPEED, sprint_speed * 1.12),
			animation_limit)
		maximum_speed = minf(starting_speed + RUN_SPEED_EXTRA, animation_limit)
	current_speed = starting_speed
	_build_spellcaster()


func _process(delta: float) -> void:
	_clock += delta
	if is_instance_valid(caster):
		caster.position.y = 2.45 + 0.10 * sin(_clock * 1.8)
	if is_instance_valid(spell_orb) and spell_orb.visible and not _spell_launched:
		var pulse := 1.0 + 0.13 * sin(_clock * 7.0)
		spell_orb.scale = Vector3.ONE * pulse
	if phase == "intro":
		_intro_elapsed += delta
		if _intro_elapsed >= SPELL_LAUNCH_TIME and not _spell_launched:
			_launch_spell()
		if _intro_elapsed >= INTRO_DURATION and not _intro_signal_sent:
			_intro_signal_sent = true
			phase = "intro_done"
			intro_finished.emit()
		return
	if phase != "running":
		return
	elapsed_seconds += delta
	current_speed = minf(maximum_speed,
		starting_speed + elapsed_seconds * RUN_ACCELERATION)
	player.set_endless_run_speed(current_speed)
	_publish_left -= delta
	if _publish_left <= 0.0:
		_publish_left = 0.12
		progress_changed.emit(elapsed_seconds, current_speed)


func start_run() -> void:
	if phase == "running" or phase == "finished" or player == null:
		return
	phase = "running"
	elapsed_seconds = 0.0
	current_speed = starting_speed
	player.begin_endless_run(FORWARD, current_speed)
	progress_changed.emit(elapsed_seconds, current_speed)
	run_started.emit()


func finish_run() -> void:
	phase = "finished"
	if is_instance_valid(player):
		player.end_endless_run()
	if _spell_tween != null and _spell_tween.is_running():
		_spell_tween.kill()
	if is_instance_valid(caster_visual) and caster_visual.cast_layer != null:
		caster_visual.cast_layer.cancel()


func _build_spellcaster() -> void:
	caster = Node3D.new()
	caster.name = "FlyingSpellcaster"
	caster.position = Vector3(1.35, 2.45, 6.2)
	add_child(caster)
	caster_visual = Character.new()
	caster_visual.name = "CasterVisual"
	caster_visual.measure_metrics = false
	caster_visual.sword_layer_enabled = false
	caster_visual.sustained_cast = true
	caster.add_child(caster_visual)
	caster_visual.set_locomotion("NinjaJump_Idle_Loop", 0.9)
	caster_visual.start_cast()

	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.16
	orb_mesh.height = 0.32
	orb_mesh.radial_segments = 12
	orb_mesh.rings = 6
	spell_orb = MeshInstance3D.new()
	spell_orb.name = "ChargedSpell"
	spell_orb.mesh = orb_mesh
	spell_orb.position = Vector3(0.48, 1.38, -0.48)
	spell_orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("#c69aff")
	material.emission_enabled = true
	material.emission = Color("#a85cff")
	material.emission_energy_multiplier = 2.0
	spell_orb.material_override = material
	caster.add_child(spell_orb)


func _launch_spell() -> void:
	if not is_instance_valid(spell_orb) or player == null:
		return
	_spell_launched = true
	var target := player.global_position + Vector3(0.0, 1.15, 0.0)
	_spell_tween = create_tween()
	_spell_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_spell_tween.tween_property(spell_orb, "global_position", target, SPELL_TRAVEL_TIME)
	_spell_tween.parallel().tween_property(spell_orb, "scale", Vector3.ONE * 0.025,
		SPELL_TRAVEL_TIME)
	_spell_tween.tween_callback(spell_orb.hide)
