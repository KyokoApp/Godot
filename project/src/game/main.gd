extends Node3D
## Pulau 1 km + kamera sentuh, tetap memakai mannequin dan updater yang sama.

const FirePet = preload("res://src/game/fire_pet.gd")
const PerformancePanel = preload("res://src/game/performance_panel.gd")
const Joystick = preload("res://src/game/virtual_joystick.gd")
const Mannequin = preload("res://src/game/mannequin.gd")
const MOVE_SPEED := 5.0
const Island = preload("res://src/game/island.gd")
const Grass = preload("res://src/game/grass_field.gd")
const Orbit = preload("res://src/game/orbit_camera.gd")

const CHARACTER_HEIGHT := 1.8

var _pet: FirePet
var _attack: Button
var _sun: DirectionalLight3D
var _performance: PerformancePanel
var _hud_elapsed := 0.0
var _label: Label
var _orbit: Orbit
var _island: Island
var _player: CharacterBody3D
var _visual: Mannequin
var _joystick: Joystick
var _grass: Grass


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_player()
	_build_camera()
	_pet = FirePet.new()
	_pet.player = _player
	_pet.facing = _visual
	_pet.camera = _orbit.camera
	add_child(_pet)
	_grass = Grass.new()
	_grass.island = _island
	_grass.player = _player
	add_child(_grass)
	_build_hud()
	print("[main] pulau 1K + kamera siap")
	_confirm_boot.call_deferred()


# ---------------------------------------------------------------- dunia ----

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.52, 0.86)
	sky_mat.sky_horizon_color = Color(0.78, 0.85, 0.92)
	sky_mat.ground_bottom_color = Color(0.28, 0.34, 0.26)
	sky_mat.ground_horizon_color = Color(0.62, 0.68, 0.58)
	sky.sky_material = sky_mat
	env.sky = sky
	# Cerah agar bentuk-bentuk terbaca jelas di layar HP apa pun.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.57
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	_sun = sun
	sun.rotation_degrees = Vector3(-52.0, 135.0, 0.0)
	sun.light_energy = 0.98
	sun.shadow_enabled = true
	add_child(sun)


func _build_ground() -> void:
	_island = Island.new()
	add_child(_island)


# ------------------------------------------------------------- karakter ----

func _build_player() -> void:
	var body := CharacterBody3D.new()
	body.name = "Player"
	body.position.y = _island.surface_height(0, 0) + CHARACTER_HEIGHT / 2.0 + 0.02
	body.floor_snap_length = 1.0
	body.floor_max_angle = deg_to_rad(45)
	body.collision_layer = 2
	body.collision_mask = 1

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = CHARACTER_HEIGHT
	shape.shape = capsule
	body.add_child(shape)

	var visual := Mannequin.new()
	visual.position.y = -CHARACTER_HEIGHT / 2.0
	visual.name = "Visual"
	_visual = visual
	body.add_child(visual)

	add_child(body)
	_player = body


func _build_camera() -> void:
	_orbit = Orbit.new()
	add_child(_orbit)
	_orbit.position = _player.position + Vector3(0, 0.55, 0)


# ------------------------------------------------------------------ HUD ----

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_label = Label.new()
	_label.text = "PULAU 1K — pet api astral"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_shadow", Color(0, 0, 0, 0.8))
	_label.position = Vector2(24, 24)
	layer.add_child(_label)

	_joystick = Joystick.new()
	layer.add_child(_joystick)
	_joystick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_performance = PerformancePanel.new()
	_performance.sun = _sun
	_performance.grass = _grass
	layer.add_child(_performance)
	_performance.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_performance.offset_left = -274
	_performance.offset_right = -24
	_performance.offset_top = 24
	_performance.offset_bottom = 294
	_orbit.input_exclusion = _performance
	_attack = Button.new()
	_attack.text = "ATTACK"
	_attack.add_theme_font_size_override("font_size", 26)
	layer.add_child(_attack)
	_attack.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_attack.offset_left = -220
	_attack.offset_right = -40
	_attack.offset_top = -180
	_attack.offset_bottom = -80
	_attack.button_down.connect(_pet.attack)
	_orbit.attack_exclusion = _attack
	var aim := Label.new()
	aim.text = "+"
	aim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aim.add_theme_font_size_override("font_size", 26)
	layer.add_child(aim)
	aim.anchor_left = 0.5
	aim.anchor_top = 0.42
	aim.position -= Vector2(8, 18)


# ----------------------------------------------------------------- loop ----

func _physics_process(delta: float) -> void:
	var stick := _joystick.direction
	# Arah gerak mengikuti yaw kamera; joystick atas selalu maju di layar.
	var movement := _orbit.movement_direction(stick)
	_player.velocity.x = movement.x * MOVE_SPEED
	_player.velocity.z = movement.z * MOVE_SPEED
	if not _player.is_on_floor():
		_player.velocity += _player.get_gravity() * delta
	else:
		_player.velocity.y = 0.0
	var before := _player.position
	_player.move_and_slide()
	# Belum ada berenang: berhenti di air dangkal, bukan tenggelam ke dasar laut.
	if _island.surface_height(_player.position.x, _player.position.z) < 0.6:
		_player.position.x = before.x
		_player.position.z = before.z
		_player.velocity.x = 0
		_player.velocity.z = 0
	if _player.position.y < -15.0:
		_player.position = Vector3(0, _island.surface_height(0, 0) + 1.0, 0)
		_player.velocity = Vector3.ZERO
	var travelled := _player.position - before
	var speed := Vector2(travelled.x, travelled.z).length() / delta
	_visual.update_motion(speed)
	if movement.length_squared() > 0.001:
		var target_yaw := atan2(-movement.x, -movement.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, 1.0 - exp(-14.0 * delta))
	_orbit.follow(_player.global_position + Vector3(0, 0.55, 0), delta)


func _process(delta: float) -> void:
	_hud_elapsed += delta
	if _hud_elapsed < 0.25:
		return
	_hud_elapsed = 0.0
	_attack.text = "ATTACK" if _pet.cooldown <= 0 else "%.1f s" % _pet.cooldown
	_label.text = (
		"PULAU 1K — pet api astral\nFPS: %d | Posisi: %.1f, %.1f\n"
		+ "Kiri: gerak | Geser kanan: kamera | Cubit kanan: zoom"
	) % [Engine.get_frames_per_second(), _player.position.x, _player.position.z]


func _confirm_boot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	# Launcher memakai marker ini untuk mendeteksi boot konten yang terputus.
	DirAccess.remove_absolute("user://content_boot_pending")
