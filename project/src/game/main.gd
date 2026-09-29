extends Node3D
## Pulau 1 km + kamera sentuh, tetap memakai mannequin dan updater yang sama.

const ShaderWarmup = preload("res://src/game/loading/shader_warmup.gd")
const NatureField = preload("res://src/game/world/nature_field.gd")
const StonePath = preload("res://src/game/world/stone_path.gd")
const TerrainOcclusion = preload("res://src/game/world/terrain_occlusion.gd")
const Night = preload("res://src/game/environment/night_environment.gd")
const WorldAudio = preload("res://src/game/audio/world_audio.gd")
const Footsteps = preload("res://src/game/audio/footsteps.gd")
const RuneButton = preload("res://src/game/ui/rune_button.gd")
const FirePet = preload("res://src/game/fire_pet.gd")
const PerformancePanel = preload("res://src/game/performance_panel.gd")
const Joystick = preload("res://src/game/virtual_joystick.gd")
const Mannequin = preload("res://src/game/mannequin.gd")
const MOVE_SPEED := 5.0
const Island = preload("res://src/game/island.gd")
const Grass = preload("res://src/game/grass_field.gd")
const Orbit = preload("res://src/game/orbit_camera.gd")

const CHARACTER_HEIGHT := 1.8

var warmup_requested := false
var warmup_complete := false
var warmup_report: Dictionary = {}
var _nature: NatureField
var _stone_path: StonePath
var _previous_occlusion := false
var _audio: WorldAudio
var _footsteps: Footsteps
var _pet: FirePet
var _attack: RuneButton
var _settings: RuneButton
var _graphics_drawer: PanelContainer
var _sun: DirectionalLight3D
var _performance: PerformancePanel
var _orbit: Orbit
var _island: Island
var _player: CharacterBody3D
var _visual: Mannequin
var _joystick: Joystick
var _grass: Grass


func _ready() -> void:
	_previous_occlusion = get_viewport().use_occlusion_culling
	get_viewport().use_occlusion_culling = true
	_build_environment()
	_build_ground()
	_build_player()
	_build_camera()
	_audio = WorldAudio.new()
	_audio.listener = _orbit.camera
	add_child(_audio)
	_footsteps = Footsteps.new()
	_footsteps.audio = _audio
	_footsteps.body = _player
	_footsteps.island = _island
	_footsteps.visual = _visual
	add_child(_footsteps)
	_pet = FirePet.new()
	_pet.player = _player
	_pet.facing = _visual
	_pet.camera = _orbit.camera
	_pet.cast_started.connect(_visual.start_cast)
	add_child(_pet)
	_audio.follow_fire(_pet)
	_nature = NatureField.new()
	_nature.island = _island
	_nature.player = _player
	add_child(_nature)
	_grass = Grass.new()
	_grass.island = _island
	_grass.player = _player
	add_child(_grass)
	_build_hud()
	print("[main] pulau 1K + kamera siap")
	_confirm_boot.call_deferred()


# ---------------------------------------------------------------- dunia ----

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "NightEnvironment"
	world_environment.environment = Night.make_environment()
	add_child(world_environment)
	_sun = Night.make_moonlight()
	add_child(_sun)
	_sun.look_at_from_position(Vector3.ZERO, -Night.MOON_DIRECTION)


func _build_ground() -> void:
	_island = Island.new()
	add_child(_island)
	TerrainOcclusion.build(_island)
	_stone_path = StonePath.new()
	_stone_path.island = _island
	add_child(_stone_path)


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

	_joystick = Joystick.new()
	layer.add_child(_joystick)
	_joystick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_graphics_drawer(layer)
	_settings = RuneButton.new()
	_settings.name = "GraphicsRune"
	_settings.compact = true
	_settings.glyph = preload("res://src/game/ui/settings.svg")
	_settings.tooltip_text = "Pengaturan grafik"
	layer.add_child(_settings)
	_settings.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_settings.offset_left = -84
	_settings.offset_right = -24
	_settings.offset_top = 24
	_settings.offset_bottom = 84
	_settings.pressed.connect(_toggle_graphics)
	_orbit.input_exclusion = _settings
	_attack = RuneButton.new()
	_attack.name = "FireAttack"
	_attack.glyph = preload("res://src/game/ui/flame.svg")
	_attack.tooltip_text = "Serangan api"
	layer.add_child(_attack)
	_attack.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_attack.offset_left = -176
	_attack.offset_right = -48
	_attack.offset_top = -180
	_attack.offset_bottom = -52
	_attack.pressed.connect(_pet.attack)
	_orbit.attack_exclusion = _attack


func _build_graphics_drawer(layer: CanvasLayer) -> void:
	_graphics_drawer = PanelContainer.new()
	_graphics_drawer.name = "GraphicsDrawer"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.045, 0.12, 0.96)
	style.border_color = Color(0.55, 0.44, 0.77, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	_graphics_drawer.add_theme_stylebox_override("panel", style)
	layer.add_child(_graphics_drawer)
	_graphics_drawer.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_graphics_drawer.offset_left = -334
	_graphics_drawer.offset_right = -24
	_graphics_drawer.offset_top = 100
	_graphics_drawer.offset_bottom = 505
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_graphics_drawer.add_child(content)
	var title := Label.new()
	title.text = "GRAFIK"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("e4d8ff"))
	content.add_child(title)
	_performance = PerformancePanel.new()
	_performance.sun = _sun
	_performance.grass = _grass
	_performance.water = _island.water
	content.add_child(_performance)
	_graphics_drawer.hide()


func _toggle_graphics() -> void:
	var opened := not _graphics_drawer.visible
	_graphics_drawer.visible = opened
	_attack.visible = not opened
	_joystick.reset()
	_joystick.input_enabled = not opened
	_orbit.reset_touches()
	_orbit.input_enabled = not opened


func _input(event: InputEvent) -> void:
	if _graphics_drawer == null or not _graphics_drawer.visible:
		return
	var point := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		point = event.position
	elif event is InputEventMouseButton and event.pressed:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		point = event.position
	else:
		return
	if not _graphics_drawer.get_global_rect().has_point(point) and not _settings.contains_point(point):
		_toggle_graphics()


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
	if not _island.is_walkable_shore(_player.position.x, _player.position.z):
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
	_footsteps.update_motion(delta, speed)
	if movement.length_squared() > 0.001:
		var target_yaw := atan2(-movement.x, -movement.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, 1.0 - exp(-14.0 * delta))
	_orbit.follow(_player.global_position + Vector3(0, 0.55, 0), delta)


func _process(_delta: float) -> void:
	_attack.cooldown_fraction = clampf(_pet.cooldown / FirePet.COOLDOWN, 0, 1)
	_attack.queue_redraw()


func _confirm_boot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	# Production scene launch only; isolated tests retain their existing setup.
	if DisplayServer.get_name() != "headless" and (
			get_tree().current_scene == self or warmup_requested):
		var warmup := ShaderWarmup.new()
		add_child(warmup)
		warmup_report = await warmup.run(self)
		warmup.queue_free()
	warmup_complete = true
	# Launcher memakai marker ini untuk mendeteksi boot konten yang terputus.
	DirAccess.remove_absolute("user://content_boot_pending")


func _exit_tree() -> void:
	get_viewport().use_occlusion_culling = _previous_occlusion
