class_name SurvivalHUD
extends Control
## HUD run Survival dan pilihan buff; seluruh level/progres hidup bersama SurvivalWorld.

const AVATAR = preload("res://src/game/ui/survival_avatar.svg")
const BuffCard = preload("res://src/game/ui/survival_buff_card.gd")

var profile_panel: PanelContainer
var status_label: Label
var health_bar: ProgressBar
var health_text: Label
var level_label: Label
var kill_label: Label
var xp_bar: ProgressBar
var xp_text: Label

var _choice_layer: ColorRect
var _choice_panel: PanelContainer
var _choice_row: HBoxContainer
var _choice_title: Label
var _choice_world: Node
var _choice_locked := false
var _health_tween: Tween
var _xp_tween: Tween
var _feedback_tween: Tween
var _xp_feedback: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 100
	_build_profile()
	_build_choice_layer()
	get_viewport().size_changed.connect(_layout_for_viewport)
	_layout_for_viewport()


func update_health(value: int, maximum: int, shield: int = 0,
		shield_maximum: int = 0) -> void:
	if not is_instance_valid(health_bar):
		return
	var safe_maximum := maxi(1, maximum)
	health_bar.max_value = safe_maximum
	if _health_tween != null and _health_tween.is_running():
		_health_tween.kill()
	_health_tween = create_tween()
	_health_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_health_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_health_tween.tween_property(health_bar, "value", clampi(value, 0, safe_maximum), 0.22)
	var ratio := float(value) / float(safe_maximum)
	var health_color := Color("#63e6b4")
	if ratio < 0.34:
		health_color = Color("#ff607b")
	elif ratio < 0.67:
		health_color = Color("#ffd27a")
	var fill := _make_bar_style(health_color)
	health_bar.add_theme_stylebox_override("fill", fill)
	if shield > 0:
		health_text.text = "HP %d/%d  ·  ✦ %d/%d" % [value, safe_maximum, shield, shield_maximum]
	else:
		health_text.text = "HP %d/%d" % [value, safe_maximum]


func update_progress(data: Dictionary) -> void:
	if not is_instance_valid(level_label):
		return
	var current_level := int(data.get("level", 1))
	var current_xp := int(data.get("xp", 0))
	var required_xp := maxi(1, int(data.get("xp_to_next", 80)))
	var kills := int(data.get("kills", 0))
	level_label.text = "LEVEL %02d" % current_level
	kill_label.text = "KILL %03d" % kills
	xp_bar.max_value = required_xp
	if _xp_tween != null and _xp_tween.is_running():
		_xp_tween.kill()
	_xp_tween = create_tween()
	_xp_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_xp_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_xp_tween.tween_property(xp_bar, "value", clampi(current_xp, 0, required_xp), 0.35)
	var award := int(data.get("xp_awarded", 0))
	xp_text.text = "EXP %d / %d" % [current_xp, required_xp]
	if award > 0:
		_show_xp_feedback(award)
	if data.has("health"):
		update_health(int(data.get("health", 0)), int(data.get("max_health", 100)),
			int(data.get("shield", 0)), int(data.get("shield_capacity", 0)))


func show_buff_choices(world: Node, choices: Array, level: int) -> void:
	if _choice_locked or not is_instance_valid(world) or choices.is_empty():
		return
	_choice_world = world
	_choice_locked = true
	_choice_layer.visible = true
	_choice_layer.color = Color(0.018, 0.018, 0.035, 0.0)
	_choice_panel.modulate.a = 0.0
	_choice_panel.scale = Vector2(0.94, 0.94)
	_choice_panel.pivot_offset = _choice_panel.size * 0.5
	_clear_choice_cards()
	var chosen_count := 0
	for card_data in choices:
		var card := BuffCard.new() as SurvivalBuffCard
		_choice_row.add_child(card)
		card.configure(card_data, int(card_data.get("stack_count", 0)))
		card.pressed.connect(_on_buff_card_pressed.bind(str(card_data.get("id", ""))))
		card.reveal(float(chosen_count) * 0.09)
		chosen_count += 1
	_choice_title.text = "LEVEL %02d  ·  PILIH SATU BERKAH" % level
	_layout_for_viewport()
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_choice_layer, "color:a", 0.76, 0.28)
	tween.parallel().tween_property(_choice_panel, "modulate:a", 1.0, 0.24)
	tween.parallel().tween_property(_choice_panel, "scale", Vector2.ONE, 0.3)
	get_tree().paused = true


func _build_profile() -> void:
	profile_panel = PanelContainer.new()
	profile_panel.name = "SurvivalProfile"
	profile_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	profile_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	profile_panel.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.028, 0.034, 0.055, 0.90), Color(0.48, 0.38, 0.73, 0.75), 12))
	add_child(profile_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	profile_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(61, 61)
	portrait_frame.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.08, 0.065, 0.13, 0.94), Color(0.74, 0.57, 1.0, 0.8), 31))
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait_frame)
	var portrait := TextureRect.new()
	portrait.texture = AVATAR
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.custom_minimum_size = Vector2(55, 55)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(portrait)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 3)
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(details)

	var headings := HBoxContainer.new()
	headings.add_theme_constant_override("separation", 8)
	headings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(headings)
	level_label = Label.new()
	level_label.text = "LEVEL 01"
	level_label.add_theme_font_size_override("font_size", 16)
	level_label.add_theme_color_override("font_color", Color("#f0d185"))
	level_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	headings.add_child(level_label)
	kill_label = Label.new()
	kill_label.text = "KILL 000"
	kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kill_label.add_theme_font_size_override("font_size", 11)
	kill_label.add_theme_color_override("font_color", Color(0.73, 0.74, 0.84))
	kill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	headings.add_child(kill_label)

	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 7)
	health_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(health_row)
	health_bar = _make_progress_bar(Color("#63e6b4"), 8)
	health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_bar.value = 100
	health_row.add_child(health_bar)
	health_text = Label.new()
	health_text.text = "HP 100/100"
	health_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health_text.add_theme_font_size_override("font_size", 10)
	health_text.add_theme_color_override("font_color", Color(0.86, 0.87, 0.92))
	health_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_row.add_child(health_text)

	var xp_header := HBoxContainer.new()
	xp_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(xp_header)
	xp_text = Label.new()
	xp_text.text = "EXP 0 / 80"
	xp_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_text.add_theme_font_size_override("font_size", 9)
	xp_text.add_theme_color_override("font_color", Color(0.75, 0.66, 1.0))
	xp_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_header.add_child(xp_text)
	status_label = Label.new()
	status_label.text = "STAGE 01  ·  01:00  ·  ZOMBI 00"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.add_theme_font_size_override("font_size", 9)
	status_label.add_theme_color_override("font_color", Color(0.66, 0.70, 0.82))
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_header.add_child(status_label)

	xp_bar = _make_progress_bar(Color("#9b78ff"), 6)
	xp_bar.max_value = 80
	xp_bar.value = 0
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(xp_bar)
	_xp_feedback = Label.new()
	_xp_feedback.text = ""
	_xp_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_xp_feedback.add_theme_font_size_override("font_size", 11)
	_xp_feedback.add_theme_color_override("font_color", Color("#dfcaff"))
	_xp_feedback.add_theme_constant_override("outline_size", 2)
	_xp_feedback.add_theme_color_override("font_outline_color", Color(0.10, 0.07, 0.18, 0.9))
	_xp_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_feedback.modulate.a = 0.0
	_xp_feedback.position = Vector2(0, 4)
	add_child(_xp_feedback)


func _build_choice_layer() -> void:
	_choice_layer = ColorRect.new()
	_choice_layer.name = "BuffChoiceBackdrop"
	_choice_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choice_layer.color = Color(0.018, 0.018, 0.035, 0.0)
	_choice_layer.visible = false
	_choice_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_choice_layer)

	_choice_panel = PanelContainer.new()
	_choice_panel.name = "BuffChoicePanel"
	_choice_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_choice_panel.add_theme_stylebox_override("panel", _make_panel_style(
		Color(0.035, 0.038, 0.065, 0.99), Color(0.67, 0.55, 0.91, 0.86), 18))
	_choice_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_choice_layer.add_child(_choice_panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	_choice_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var eyebrow := Label.new()
	eyebrow.text = "BERKAH PARA PENJAGA"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_font_size_override("font_size", 10)
	eyebrow.add_theme_color_override("font_color", Color("#bb9cff"))
	content.add_child(eyebrow)
	var title := Label.new()
	title.name = "Title"
	_choice_title = title
	title.text = "LEVEL 05  ·  PILIH SATU BERKAH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color("#f3e4ba"))
	content.add_child(title)
	var hint := Label.new()
	hint.text = "Pilih 1 dari 3 kartu. Buff berlaku sampai run ini berakhir."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.72, 0.72, 0.81))
	content.add_child(hint)

	_choice_row = HBoxContainer.new()
	_choice_row.name = "CardRow"
	_choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_row.add_theme_constant_override("separation", 10)
	_choice_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_choice_row)
	var footer := Label.new()
	footer.text = "WAKTU BERHENTI SAAT MEMILIH"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 9)
	footer.add_theme_color_override("font_color", Color(0.56, 0.57, 0.68))
	content.add_child(footer)


func _layout_for_viewport() -> void:
	if not is_instance_valid(profile_panel) or not is_instance_valid(_choice_panel):
		return
	var viewport := get_viewport_rect().size
	var profile_width := minf(370.0, maxf(240.0, viewport.x - 32.0))
	profile_panel.position = Vector2(16, 16)
	profile_panel.size = Vector2(profile_width, 126)
	var panel_width := minf(920.0, maxf(280.0, viewport.x - 24.0))
	var panel_height := minf(520.0, maxf(260.0, viewport.y - 24.0))
	_choice_panel.size = Vector2(panel_width, panel_height)
	_choice_panel.position = (viewport - _choice_panel.size) * 0.5
	_choice_panel.pivot_offset = _choice_panel.size * 0.5
	var card_width := maxf(80.0, (panel_width - 64.0) / 3.0)
	var card_height := maxf(158.0, minf(232.0, panel_height - 150.0))
	for card in _choice_row.get_children():
		if card is Control:
			card.custom_minimum_size = Vector2(card_width, card_height)


func _on_buff_card_pressed(buff_id: String) -> void:
	if not _choice_locked or buff_id.is_empty():
		return
	_choice_locked = false
	for child in _choice_row.get_children():
		if child is SurvivalBuffCard:
			child.disabled = true
			var card_tween := create_tween()
			card_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			card_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			if child.buff_id == buff_id:
				card_tween.tween_property(child, "scale", Vector2(1.04, 1.04), 0.12)
			else:
				card_tween.parallel().tween_property(child, "modulate:a", 0.22, 0.16)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.12)
	tween.tween_property(_choice_panel, "modulate:a", 0.0, 0.20)
	tween.parallel().tween_property(_choice_layer, "color:a", 0.0, 0.24)
	tween.tween_callback(_finish_buff_choice.bind(buff_id))


func _finish_buff_choice(buff_id: String) -> void:
	_choice_layer.visible = false
	var world := _choice_world
	_choice_world = null
	if is_instance_valid(world):
		world.call("choose_buff", buff_id)
	_choice_locked = false
	get_tree().paused = false


func _clear_choice_cards() -> void:
	for child in _choice_row.get_children():
		_choice_row.remove_child(child)
		child.queue_free()


func _show_xp_feedback(amount: int) -> void:
	if _feedback_tween != null and _feedback_tween.is_running():
		_feedback_tween.kill()
	_xp_feedback.text = "+%d EXP" % amount
	var feedback_y := profile_panel.position.y + profile_panel.size.y - 23.0
	_xp_feedback.position = Vector2(profile_panel.position.x + profile_panel.size.x - 104.0,
		feedback_y)
	_xp_feedback.visible = profile_panel.visible
	_xp_feedback.modulate = Color(1, 1, 1, 1)
	_feedback_tween = create_tween()
	_feedback_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_feedback_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(_xp_feedback, "position:y", feedback_y - 11.0, 0.7)
	_feedback_tween.parallel().tween_property(_xp_feedback, "modulate:a", 0.0, 0.8)


func _make_progress_bar(color: Color, thickness: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(72, thickness)
	bar.show_percentage = false
	bar.min_value = 0
	bar.max_value = 100
	bar.add_theme_stylebox_override("background", _make_panel_style(
		Color(0.15, 0.15, 0.20, 0.95), Color(0.34, 0.34, 0.43, 0.25), 8))
	bar.add_theme_stylebox_override("fill", _make_bar_style(color))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _make_bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


func _make_panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style
