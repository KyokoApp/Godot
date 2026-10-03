extends Node
## Jembatan input NPC: tombol dekat karakter, kunci gerak, lalu pulihkan HUD
## setelah layar pilihan ditutup.

const Dialogue = preload("res://src/game/ui/npc_dialogue.gd")

const INTERACT_DISTANCE := 2.8

var player: CharacterBody3D
var npc: Node3D
var joystick: Control
var orbit: Node
var canvas_layer: CanvasLayer
var controls_to_hide: Array[Control] = []

var _prompt: Button
var _dialogue: Dialogue
var _modal_open := false
var _saved_visibility: Dictionary = {}
var _saved_joystick_input := true
var _saved_orbit_input := true


func _ready() -> void:
	_build_prompt()
	_build_dialogue()
	_add_input_exclusions()
	get_viewport().size_changed.connect(_place_prompt)
	_place_prompt()


func _process(_delta: float) -> void:
	if _modal_open or player == null or npc == null:
		return
	_prompt.visible = _distance_to_npc() <= INTERACT_DISTANCE


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	if _modal_open:
		if key.keycode == KEY_ESCAPE or key.keycode == KEY_E:
			_dialogue.call("close_dialogue")
		elif key.keycode == KEY_UP:
			_dialogue.call("move_selection", -1)
		elif key.keycode == KEY_DOWN:
			_dialogue.call("move_selection", 1)
		elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE:
			_dialogue.call("activate_selected")
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_E and _prompt.visible:
		_begin_interaction()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _modal_open


func _build_prompt() -> void:
	_prompt = Button.new()
	_prompt.name = "TalkPrompt"
	_prompt.text = "E   /   BICARA"
	_prompt.custom_minimum_size = Vector2(220, 62)
	_prompt.focus_mode = Control.FOCUS_NONE
	_prompt.mouse_filter = Control.MOUSE_FILTER_STOP
	_prompt.add_theme_font_size_override("font_size", 18)
	_prompt.add_theme_color_override("font_color", Color("fff4d8"))
	var normal := _prompt_style(Color(0.10, 0.085, 0.13, 0.94), Color("f2bd35"))
	var hover := _prompt_style(Color("30263b"), Color("ffe074"))
	_prompt.add_theme_stylebox_override("normal", normal)
	_prompt.add_theme_stylebox_override("hover", hover)
	_prompt.add_theme_stylebox_override("pressed", hover)
	_prompt.pressed.connect(_begin_interaction)
	canvas_layer.add_child(_prompt)
	_prompt.hide()


func _build_dialogue() -> void:
	_dialogue = Dialogue.new()
	_dialogue.name = "NPCDialogue"
	_dialogue.closed.connect(_on_dialogue_closed)
	canvas_layer.add_child(_dialogue)


func _add_input_exclusions() -> void:
	if joystick != null:
		var joystick_exclusions: Array = joystick.get("input_exclusions")
		joystick_exclusions.append(_prompt)
		joystick_exclusions.append(_dialogue)
		joystick.set("input_exclusions", joystick_exclusions)
	if orbit != null:
		var orbit_exclusions: Array = orbit.get("exclusions")
		orbit_exclusions.append(_prompt)
		orbit_exclusions.append(_dialogue)
		orbit.set("exclusions", orbit_exclusions)


func _place_prompt() -> void:
	if _prompt == null:
		return
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -110.0
	_prompt.offset_right = 110.0
	_prompt.offset_top = -132.0
	_prompt.offset_bottom = -70.0


func _begin_interaction() -> void:
	if _modal_open or player == null or npc == null or _distance_to_npc() > INTERACT_DISTANCE:
		return
	_modal_open = true
	_prompt.hide()
	_saved_visibility.clear()
	for control in controls_to_hide:
		if not is_instance_valid(control):
			continue
		_saved_visibility[control] = control.visible
		control.hide()
	if joystick != null:
		_saved_joystick_input = bool(joystick.get("input_enabled"))
		joystick.set("input_enabled", false)
		joystick.call("reset")
	if orbit != null:
		_saved_orbit_input = bool(orbit.get("input_enabled"))
		orbit.set("input_enabled", false)
		orbit.call("reset_touches")
	player.velocity = Vector3.ZERO
	player.set("move_speed", 0.0)
	_face_pair()
	npc.call("start_conversation", player.global_position)
	var character_name := str(npc.get("display_name"))
	_dialogue.call("open_dialogue", character_name)


func _on_dialogue_closed() -> void:
	if not _modal_open:
		return
	_modal_open = false
	if is_instance_valid(npc):
		npc.call("end_conversation")
	for control: Control in _saved_visibility:
		if is_instance_valid(control):
			control.visible = bool(_saved_visibility[control])
	_saved_visibility.clear()
	if joystick != null and is_instance_valid(joystick):
		joystick.set("input_enabled", _saved_joystick_input)
		joystick.call("reset")
	if orbit != null and is_instance_valid(orbit):
		orbit.set("input_enabled", _saved_orbit_input)
		orbit.call("reset_touches")
	_prompt.hide()


func _face_pair() -> void:
	var player_direction := Vector2(
		npc.global_position.x - player.global_position.x,
		npc.global_position.z - player.global_position.z
	)
	var npc_direction := -player_direction
	var player_visual := player.get("visual") as Node3D
	var npc_visual := npc.get("visual") as Node3D
	if player_visual != null and player_direction.length_squared() > 0.001:
		player_visual.rotation.y = atan2(-player_direction.x, -player_direction.y)
	if npc_visual != null and npc_direction.length_squared() > 0.001:
		npc_visual.rotation.y = atan2(-npc_direction.x, -npc_direction.y)


func _distance_to_npc() -> float:
	return Vector2(player.global_position.x, player.global_position.z).distance_to(
		Vector2(npc.global_position.x, npc.global_position.z)
	)


func _prompt_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
