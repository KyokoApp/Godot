extends Node3D
## World-only game scene: satu pulau dan player berupa nyala api biru.

const Field = preload("res://src/game/world/field.gd")
const Scenery = preload("res://src/game/world/scenery.gd")
const Forest = preload("res://src/game/world/forest.gd")
const Grass = preload("res://src/game/grass_field.gd")
const Player = preload("res://src/game/flame_player.gd")
const Orbit = preload("res://src/game/orbit_camera.gd")
const Joystick = preload("res://src/game/virtual_joystick.gd")
const Dusk = preload("res://src/game/environment/dusk_environment.gd")

## Dipertahankan sebagai penanda versi gameplay untuk pemeriksaan PCK incremental.
const MOVE_SPEED := 5.0
const SPAWN := Vector2(0.0, 7.0)
const BOOT_TRACE := "user://boot_trace.txt"
const BOOT_READY := "game ready"
const UPDATE_RESUME := "user://in_game_update_resume.cfg"

var _previous_occlusion := false
var _field: Field
var _scenery: Scenery
var _forest: Forest
var _grass: Grass
var _player: Player
var _orbit: Orbit
var _joystick: Joystick
var _update_button: Button
var _sun: DirectionalLight3D
var _spawn_point := SPAWN
var _resume_camera: Dictionary = {}
var _resume_loaded := false


func _ready() -> void:
	_load_resume_state()
	_previous_occlusion = get_viewport().use_occlusion_culling
	get_viewport().use_occlusion_culling = true
	_build_environment()
	_build_world()
	_build_player()
	_build_camera()
	_build_grass()
	_build_controls()
	print("[main] world pulau + player api biru siap")
	_confirm_boot.call_deferred()


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "DuskEnvironment"
	world_environment.environment = Dusk.make_environment()
	add_child(world_environment)
	_sun = Dusk.make_sunlight()
	add_child(_sun)
	_sun.look_at_from_position(Vector3.ZERO, -Dusk.SUN_DIRECTION)


func _build_world() -> void:
	_field = Field.new()
	add_child(_field)
	_scenery = Scenery.new()
	add_child(_scenery)
	_forest = Forest.new()
	add_child(_forest)


func _build_player() -> void:
	_player = Player.new()
	_player.name = "Player"
	_player.field = _field
	_player.max_speed = MOVE_SPEED
	_field.player = _player
	add_child(_player)
	_player.spawn(_spawn_point)


func _build_camera() -> void:
	_orbit = Orbit.new()
	_orbit.name = "FollowCamera"
	_orbit.distance = 8.0
	_orbit.pitch = 0.48
	_orbit.pitch_min = 0.12
	_orbit.pitch_max = 1.15
	_orbit.focus_offset = Vector3(0.0, 0.18, 0.0)
	if _resume_loaded:
		_orbit.yaw = float(_resume_camera.get("yaw", _orbit.yaw))
		_orbit.pitch = clampf(float(_resume_camera.get("pitch", _orbit.pitch)),
			_orbit.pitch_min, _orbit.pitch_max)
		_orbit.distance = clampf(float(_resume_camera.get("distance", _orbit.distance)),
			Orbit.MIN_DISTANCE, Orbit.MAX_DISTANCE)
	add_child(_orbit)
	_orbit.position = _player.global_position + _orbit.focus_offset
	_player.orbit = _orbit


func _build_grass() -> void:
	_grass = Grass.new()
	_grass.name = "Grass"
	_grass.ground = _field
	_grass.player = _player
	add_child(_grass)


func _build_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TouchControls"
	add_child(layer)
	_joystick = Joystick.new()
	_joystick.name = "MovementAnalog"
	layer.add_child(_joystick)
	_joystick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player.joystick = _joystick

	_update_button = Button.new()
	_update_button.name = "UpdateContentButton"
	_update_button.text = "↻"
	_update_button.tooltip_text = "Periksa pembaruan konten"
	_update_button.custom_minimum_size = Vector2(46, 46)
	_update_button.focus_mode = Control.FOCUS_NONE
	_update_button.add_theme_font_size_override("font_size", 20)
	_update_button.add_theme_color_override("font_color", Color("b9e6ff"))
	_update_button.add_theme_color_override("font_hover_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.025, 0.07, 0.14, 0.72)
	normal.border_color = Color(0.24, 0.66, 1.0, 0.55)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(23)
	_update_button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.06, 0.16, 0.28, 0.92)
	_update_button.add_theme_stylebox_override("hover", hover)
	layer.add_child(_update_button)
	_update_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_update_button.offset_left = -64
	_update_button.offset_top = 18
	_update_button.offset_right = -18
	_update_button.offset_bottom = 64
	_update_button.pressed.connect(_open_update_flow)
	_joystick.input_exclusions = [_update_button]
	_orbit.exclusions = [_update_button]


func _load_resume_state() -> void:
	if not FileAccess.file_exists(UPDATE_RESUME):
		return
	var config := ConfigFile.new()
	if config.load(UPDATE_RESUME) != OK:
		DirAccess.remove_absolute(UPDATE_RESUME)
		return
	_spawn_point = Vector2(
		float(config.get_value("player", "x", SPAWN.x)),
		float(config.get_value("player", "z", SPAWN.y)))
	_resume_camera = {
		"yaw": float(config.get_value("camera", "yaw", 0.0)),
		"pitch": float(config.get_value("camera", "pitch", 0.48)),
		"distance": float(config.get_value("camera", "distance", 8.0)),
	}
	_resume_loaded = true


func _save_resume_state() -> bool:
	if _player == null or _orbit == null:
		return false
	var config := ConfigFile.new()
	config.set_value("player", "x", _player.global_position.x)
	config.set_value("player", "z", _player.global_position.z)
	config.set_value("camera", "yaw", _orbit.yaw)
	config.set_value("camera", "pitch", _orbit.pitch)
	config.set_value("camera", "distance", _orbit.distance)
	return config.save(UPDATE_RESUME) == OK


func _open_update_flow() -> void:
	if _player == null or _orbit == null:
		return
	if not ResourceLoader.exists("res://launcher/main.tscn"):
		push_warning("Launcher pembaruan tidak tersedia di build ini.")
		return
	if not _save_resume_state():
		push_warning("Posisi player tidak bisa disimpan untuk kembali dari update.")
		return
	if get_tree().change_scene_to_file("res://launcher/main.tscn") != OK:
		DirAccess.remove_absolute(UPDATE_RESUME)
		push_error("Layar pembaruan tidak bisa dibuka.")


func _physics_process(delta: float) -> void:
	if _orbit == null or _player == null:
		return
	_orbit.follow(_player.global_position + _orbit.focus_offset, delta)


func _confirm_boot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_write_boot_marker()


func _write_boot_marker() -> void:
	var file := FileAccess.open(BOOT_TRACE, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(BOOT_TRACE, FileAccess.WRITE)
	if file != null:
		file.seek_end()
		file.store_line("%s %s" % [Time.get_datetime_string_from_system(false, true), BOOT_READY])
		file.close()
	# Launcher memakai marker ini untuk memulihkan unduhan yang terputus saat boot.
	DirAccess.remove_absolute("user://content_boot_pending")
	if _resume_loaded:
		DirAccess.remove_absolute(UPDATE_RESUME)


func _exit_tree() -> void:
	get_viewport().use_occlusion_culling = _previous_occlusion
