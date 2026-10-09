extends Node
## Jembatan input NPC: tombol dekat karakter, kunci gerak, lalu pulihkan HUD
## setelah layar pilihan ditutup. Versi cozy: interaksi bukan menu fullscreen
## tapi bubble chat "Test Arena - Coming Soon" + animasi kamera.

signal gameplay_requested

const Dialogue = preload("res://src/game/ui/npc_dialogue.gd")
const UpgradeMenu = preload("res://src/game/ui/attribute_upgrade_menu.gd")

const INTERACT_DISTANCE := 2.8

var player: CharacterBody3D
var npc: Node3D
var joystick: Control
var orbit: Node
var canvas_layer: CanvasLayer
var meta_progress: Object
var controls_to_hide: Array[Control] = []

var _prompt: Button
var _dialogue: Dialogue
var _upgrade_menu: Control
var _bubble: PanelContainer
var _bubble_title: Label
var _bubble_sub: Label
var _modal_open := false
var _saved_visibility: Dictionary = {}
var _saved_joystick_input := true
var _saved_orbit_input := true
var _saved_orbit_yaw := 0.0
var _saved_orbit_pitch := 0.0
var _saved_orbit_distance := 0.0
var _saved_orbit_focus := Vector3.ZERO
var _camera_tween: Tween
var _dialogue_close_done := false
var _camera_restore_done := true
var _pending_gameplay := false
var _bubble_tween: Tween


func _ready() -> void:
	_build_prompt()
	_build_dialogue()
	_build_upgrade_menu()
	_build_bubble()
	_add_input_exclusions()
	get_viewport().size_changed.connect(_place_prompt)
	_place_prompt()


func _process(_delta: float) -> void:
	# update bubble posisi biar nempel di samping NPC
	if _bubble != null and _bubble.visible and npc != null and is_instance_valid(npc):
		_update_bubble_position()
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
		if _is_headless():
			if _upgrade_menu != null and _upgrade_menu.visible:
				if key.keycode == KEY_ESCAPE or key.keycode == KEY_E:
					_upgrade_menu.call("close")
			else:
				if key.keycode == KEY_ESCAPE or key.keycode == KEY_E:
					_dialogue.call("close_dialogue")
				elif key.keycode == KEY_UP:
					_dialogue.call("move_selection", -1)
				elif key.keycode == KEY_DOWN:
					_dialogue.call("move_selection", 1)
				elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER \
						or key.keycode == KEY_SPACE:
					_dialogue.call("activate_selected")
		else:
			# cozy: ESC/E tutup bubble lebih cepat
			if key.keycode == KEY_ESCAPE or key.keycode == KEY_E:
				_cozy_close()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_E and _prompt.visible:
		_begin_interaction()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _modal_open


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


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
	_dialogue.closing.connect(_on_dialogue_closing)
	_dialogue.closed.connect(_on_dialogue_closed)
	_dialogue.gameplay_requested.connect(_on_gameplay_requested)
	_dialogue.upgrade_requested.connect(_open_upgrade_menu)
	canvas_layer.add_child(_dialogue)


func _build_upgrade_menu() -> void:
	_upgrade_menu = UpgradeMenu.new()
	_upgrade_menu.meta_progress = meta_progress
	canvas_layer.add_child(_upgrade_menu)


func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	_bubble.name = "ArenaBubble"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.10, 0.92)
	style.border_color = Color("f2bd35")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_bubble.add_theme_stylebox_override("panel", style)
	canvas_layer.add_child(_bubble)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_bubble.add_child(vbox)
	_bubble_title = Label.new()
	_bubble_title.text = "Test Arena"
	_bubble_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_title.add_theme_font_size_override("font_size", 20)
	_bubble_title.add_theme_color_override("font_color", Color("fff4d8"))
	vbox.add_child(_bubble_title)
	_bubble_sub = Label.new()
	_bubble_sub.text = "Coming Soon"
	_bubble_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_sub.add_theme_font_size_override("font_size", 12)
	_bubble_sub.add_theme_color_override("font_color", Color("f2bd35"))
	vbox.add_child(_bubble_sub)
	var hint := Label.new()
	hint.text = "Arena PvP cozy segera hadir"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color("cfc6d4"))
	vbox.add_child(hint)
	_bubble.hide()
	_bubble.modulate = Color(1, 1, 1, 0)


func _update_bubble_position() -> void:
	if _bubble == null or npc == null or not is_instance_valid(npc):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		# fallback tengah
		var vp := get_viewport().get_visible_rect().size
		_bubble.position = (vp - _bubble.size) * 0.5
		return
	var world_pos := npc.global_position + Vector3(0, 1.9, 0)
	var screen := cam.unproject_position(world_pos)
	var vp := get_viewport().get_visible_rect().size
	# taruh di kanan atas NPC, dengan offset cozy
	var target := screen + Vector2(28, -74)
	# clamp biar tidak keluar layar
	target.x = clampf(target.x, 12, vp.x - _bubble.size.x - 12)
	target.y = clampf(target.y, 12, vp.y - _bubble.size.y - 12)
	_bubble.position = target


func _open_upgrade_menu() -> void:
	if not _modal_open or _upgrade_menu == null:
		return
	_upgrade_menu.set("meta_progress", meta_progress)
	_upgrade_menu.call("open")


func _add_input_exclusions() -> void:
	if joystick != null:
		var joystick_exclusions: Array = joystick.get("input_exclusions")
		joystick_exclusions.append(_prompt)
		joystick_exclusions.append(_dialogue)
		joystick_exclusions.append(_upgrade_menu)
		if _bubble != null:
			joystick_exclusions.append(_bubble)
		joystick.set("input_exclusions", joystick_exclusions)
	if orbit != null:
		var orbit_exclusions: Array = orbit.get("exclusions")
		orbit_exclusions.append(_prompt)
		orbit_exclusions.append(_dialogue)
		orbit_exclusions.append(_upgrade_menu)
		if _bubble != null:
			orbit_exclusions.append(_bubble)
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
	if _is_headless():
		_begin_interaction_classic()
	else:
		_begin_interaction_cozy()


func _begin_interaction_classic() -> void:
	if _modal_open or player == null or npc == null or _distance_to_npc() > INTERACT_DISTANCE:
		return
	_modal_open = true
	_pending_gameplay = false
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
	_dialogue_close_done = false
	_camera_restore_done = orbit == null
	player.velocity = Vector3.ZERO
	player.set("move_speed", 0.0)
	_face_pair()
	_focus_conversation_camera()
	npc.call("start_conversation", player.global_position)
	var character_name := str(npc.get("display_name"))
	_dialogue.call("open_dialogue", character_name)


func _begin_interaction_cozy() -> void:
	if _modal_open or player == null or npc == null or _distance_to_npc() > INTERACT_DISTANCE:
		return
	_modal_open = true
	_pending_gameplay = false
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
	_dialogue_close_done = false
	_camera_restore_done = false
	player.velocity = Vector3.ZERO
	player.set("move_speed", 0.0)
	_face_pair()
	_focus_conversation_camera()
	npc.call("start_conversation", player.global_position)
	_show_cozy_bubble()
	# auto close setelah 3 detik cozy
	get_tree().create_timer(2.8).timeout.connect(_cozy_close)


func _show_cozy_bubble() -> void:
	if _bubble == null:
		_dialogue_close_done = true
		return
	_bubble.show()
	_update_bubble_position()
	_bubble.modulate = Color(1, 1, 1, 0)
	_bubble.scale = Vector2(0.82, 0.82)
	_bubble.pivot_offset = _bubble.size * 0.5
	if _bubble_tween != null and _bubble_tween.is_running():
		_bubble_tween.kill()
	_bubble_tween = create_tween().set_parallel(true)
	_bubble_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bubble_tween.tween_property(_bubble, "modulate", Color.WHITE, 0.34)
	_bubble_tween.tween_property(_bubble, "scale", Vector2.ONE, 0.38)
	_dialogue_close_done = false
	# bubble dianggap “dialog” sudah terbuka, jadi tidak perlu closing dialogue
	# _dialogue_close_done akan di-set true saat bubble mulai menghilang


func _cozy_close() -> void:
	if not _modal_open:
		return
	# cegah double close
	if _bubble_tween != null and _bubble_tween.is_running():
		# biarkan tween jalan, tapi jangan duplicate
		pass
	# animasi bubble hilang
	if _bubble != null and _bubble.visible:
		if _bubble_tween != null and _bubble_tween.is_running():
			_bubble_tween.kill()
		_bubble_tween = create_tween().set_parallel(true)
		_bubble_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_bubble_tween.tween_property(_bubble, "modulate", Color(1, 1, 1, 0), 0.22)
		_bubble_tween.tween_property(_bubble, "scale", Vector2(0.86, 0.86), 0.22)
		_bubble_tween.finished.connect(func():
			if _bubble != null:
				_bubble.hide()
		)
	_dialogue_close_done = true
	_on_dialogue_closing()
	# _finish_close_if_ready akan nunggu kamera


func _focus_conversation_camera() -> void:
	if orbit == null or player == null or npc == null:
		_camera_restore_done = true
		return
	_saved_orbit_yaw = float(orbit.get("yaw"))
	_saved_orbit_pitch = float(orbit.get("pitch"))
	_saved_orbit_distance = float(orbit.get("distance"))
	_saved_orbit_focus = orbit.get("focus_offset")
	_camera_restore_done = false

	# Arah NPC dijadikan sisi kanan kamera agar Mira masuk ke area kanan,
	# tanpa SubViewport atau panggung putih yang menutupi dunia aktif.
	var toward_npc := Vector2(
		npc.global_position.x - player.global_position.x,
		npc.global_position.z - player.global_position.z
	)
	var separation := toward_npc.length()
	if separation < 0.01:
		toward_npc = Vector2(0.0, -1.0)
	else:
		toward_npc /= separation
	# Sedikit dari sisi pemain memberi wajah Mira sudut tiga perempat, bukan profil penuh.
	var desired_yaw := atan2(-toward_npc.y, toward_npc.x) + 0.14
	var current_yaw := float(orbit.get("yaw"))
	var target_yaw := current_yaw + wrapf(desired_yaw - current_yaw, -PI, PI)
	var viewport_size := get_viewport().get_visible_rect().size
	var landscape := viewport_size.x >= viewport_size.y
	var target_distance := 2.7 if landscape else 5.0
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var half_horizontal_fov := atan(tan(deg_to_rad(65.0) * 0.5) * aspect)
	var frame_width := 2.0 * target_distance * tan(half_horizontal_fov)
	# Komposisi kamera memusatkan NPC kira-kira di 3/4 layar. Jika jarak
	# percakapan lebar, fokus bergeser ke tengah pasangan agar Mira tidak terpotong.
	var focus_ratio := clampf(1.0 - frame_width * 0.24 / maxf(separation, 0.01), 0.0, 0.45)
	var focus_point := player.global_position.lerp(npc.global_position, focus_ratio)
	focus_point.y += 0.35
	var focus_offset := focus_point - player.global_position
	var tween := _new_camera_tween(Tween.EASE_OUT)
	tween.tween_property(orbit, "yaw", target_yaw, 0.56)
	tween.tween_property(orbit, "pitch", 0.16, 0.56)
	tween.tween_property(orbit, "distance", target_distance, 0.56)
	tween.tween_property(orbit, "focus_offset", focus_offset, 0.56)


func _on_dialogue_closing() -> void:
	if not _modal_open:
		return
	if not _is_headless():
		_dialogue_close_done = true
	if orbit == null or not is_instance_valid(orbit):
		_camera_restore_done = true
		return
	_camera_restore_done = false
	var tween := _new_camera_tween(Tween.EASE_IN_OUT)
	tween.tween_property(orbit, "yaw", _saved_orbit_yaw, 0.48)
	tween.tween_property(orbit, "pitch", _saved_orbit_pitch, 0.48)
	tween.tween_property(orbit, "distance", _saved_orbit_distance, 0.48)
	tween.tween_property(orbit, "focus_offset", _saved_orbit_focus, 0.48)
	tween.finished.connect(_on_camera_restored)


func _on_dialogue_closed() -> void:
	if not _modal_open:
		return
	_dialogue_close_done = true
	_finish_close_if_ready()


func _on_camera_restored() -> void:
	_camera_restore_done = true
	_finish_close_if_ready()


func _finish_close_if_ready() -> void:
	if not _modal_open or not _dialogue_close_done or not _camera_restore_done:
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
	if _bubble != null:
		_bubble.hide()
		_bubble.modulate = Color(1, 1, 1, 0)
	if _pending_gameplay:
		_pending_gameplay = false
		gameplay_requested.emit()


func _on_gameplay_requested() -> void:
	_pending_gameplay = true


func _new_camera_tween(ease: int) -> Tween:
	if _camera_tween != null and _camera_tween.is_running():
		_camera_tween.kill()
	_camera_tween = create_tween().set_parallel(true)
	_camera_tween.set_trans(Tween.TRANS_CUBIC).set_ease(ease)
	return _camera_tween


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
