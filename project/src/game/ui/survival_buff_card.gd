class_name SurvivalBuffCard
extends Button
## Kartu buff dengan reveal bertahap dan respons hover yang lembut.

const BuffIcon = preload("res://src/game/ui/survival_buff_icon.gd")

var buff_id := ""
var accent := Color("#bd83ff")
var _hover_tween: Tween
var _icon: SurvivalBuffIcon
var _rarity_label: Label
var _stack_label: Label
var _name_label: Label
var _description_label: Label
var _footer_label: Label
var _card_data: Dictionary = {}
var _stack_count := 0


func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("normal", _make_style(Color(0.055, 0.06, 0.095, 0.96), 0.58))
	add_theme_stylebox_override("hover", _make_style(Color(0.10, 0.075, 0.15, 0.99), 0.95))
	add_theme_stylebox_override("pressed", _make_style(Color(0.14, 0.09, 0.20, 1.0), 1.0))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_build_content()
	_refresh_text()


func configure(card: Dictionary, stack_count: int) -> void:
	_card_data = card.duplicate(true)
	_stack_count = stack_count
	buff_id = str(card.get("id", ""))
	accent = Color(str(card.get("accent", "#bd83ff")))
	if is_inside_tree():
		add_theme_stylebox_override("normal", _make_style(Color(0.055, 0.06, 0.095, 0.96), 0.58))
		add_theme_stylebox_override("hover", _make_style(Color(0.10, 0.075, 0.15, 0.99), 0.95))
		add_theme_stylebox_override("pressed", _make_style(Color(0.14, 0.09, 0.20, 1.0), 1.0))
		_refresh_text()


func reveal(delay: float) -> void:
	modulate.a = 0.0
	pivot_offset = custom_minimum_size * 0.5
	scale = Vector2(0.88, 0.88)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(delay)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.24)
	tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.32)


func _build_content() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(header)
	_rarity_label = Label.new()
	_rarity_label.add_theme_font_size_override("font_size", 10)
	_rarity_label.add_theme_color_override("font_color", accent)
	_rarity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rarity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_rarity_label)
	_stack_label = Label.new()
	_stack_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stack_label.add_theme_font_size_override("font_size", 10)
	_stack_label.add_theme_color_override("font_color", Color(0.73, 0.74, 0.83))
	_stack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_stack_label)

	_icon = BuffIcon.new() as SurvivalBuffIcon
	_icon.custom_minimum_size = Vector2(60, 60)
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_icon)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", Color(0.97, 0.96, 1.0))
	_name_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_name_label)

	_description_label = Label.new()
	_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_description_label.add_theme_font_size_override("font_size", 11)
	_description_label.add_theme_color_override("font_color", Color(0.72, 0.73, 0.82))
	_description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_description_label)

	var footer := Label.new()
	footer.text = "PILIH BERKAH"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 9)
	footer.add_theme_color_override("font_color", Color(accent.r, accent.g, accent.b, 0.78))
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(footer)
	_footer_label = footer


func _refresh_text() -> void:
	if _card_data.is_empty() or not is_instance_valid(_name_label):
		return
	_rarity_label.text = str(_card_data.get("rarity", "BUFF"))
	_rarity_label.add_theme_color_override("font_color", accent)
	_stack_label.text = "%d/%d" % [_stack_count, int(_card_data.get("max_stacks", 1))]
	_name_label.text = str(_card_data.get("name", "BERKAH"))
	_description_label.text = str(_card_data.get("description", ""))
	_icon.icon_kind = str(_card_data.get("icon", "flame"))
	_icon.accent = accent
	_icon.queue_redraw()
	_footer_label.add_theme_color_override("font_color",
		Color(accent.r, accent.g, accent.b, 0.78))
	custom_minimum_size = Vector2(144, 184)


func _make_style(background: Color, glow: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(accent.r, accent.g, accent.b, glow)
	style.set_border_width_all(1)
	style.set_corner_radius_all(13)
	style.shadow_color = Color(accent.r, accent.g, accent.b, glow * 0.18)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 0
	style.content_margin_top = 0
	style.content_margin_right = 0
	style.content_margin_bottom = 0
	return style


func _on_mouse_entered() -> void:
	if _hover_tween != null and _hover_tween.is_running():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_hover_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", Vector2(1.035, 1.035), 0.15)


func _on_mouse_exited() -> void:
	if _hover_tween != null and _hover_tween.is_running():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_hover_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", Vector2.ONE, 0.16)
