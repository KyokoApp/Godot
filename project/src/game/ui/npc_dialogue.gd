extends Control
## Menu interaksi pop-art layar penuh: dunia tetap terlihat di balik panel.

signal closing
signal closed
signal gameplay_requested

const INK := Color("201d29")
const PAPER := Color("f4f0e7")
const GOLD := Color("f2bd35")
const RED := Color("d94a42")
const OPTION_NAMES: Array[String] = [
	"GAMEPLAY",
	"INVENTARIS",
	"STATUS KARAKTER",
	"KEMBALI",
]

var _backdrop: ColorRect
var _page: Control
var _sidebar: Polygon2D
var _side_edge: Polygon2D
var _footer: ColorRect
var _message_panel: Panel
var _left_group: Control
var _brand: Label
var _speaker: Label
var _title: Label
var _subheading: Label
var _message: Label
var _stage_label: Label
var _notice: Label
var _footer_left: Label
var _footer_right: Label
var _options: Array[Button] = []
var _option_labels: Array[Label] = []
var _option_hints: Array[Label] = []
var _selected := 0
var _closing := false
var _compact := false
var _portrait_layout := false
var _page_size := Vector2.ZERO
var _left_group_home := Vector2.ZERO
var _footer_height := 60.0
var _sidebar_shift := 0.0
var _transition: Tween


func _ready() -> void:
	name = "NPCDialogue"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()
	get_viewport().size_changed.connect(_layout)


func open_dialogue(character_name: String) -> void:
	if _closing:
		return
	_speaker.text = "SOCIAL LINK  /  " + character_name.to_upper()
	_title.text = character_name.to_upper()
	_stage_label.text = character_name.to_upper() + "  /  PENJAGA PADANG"
	_message.text = "Hai, penjelajah. Mau melihat apa?"
	_notice.text = "PILIH AKTIVITAS UNTUK MULAI"
	_selected = 0
	_refresh_options()
	visible = true
	_closing = false
	_set_open_pose()
	var tween := _new_transition(Tween.EASE_OUT)
	tween.tween_property(_backdrop, "color", Color(0.025, 0.02, 0.04, 0.38), 0.32)
	tween.tween_property(_page, "modulate", Color.WHITE, 0.38)
	tween.tween_property(_sidebar, "position", Vector2.ZERO, 0.50)
	tween.tween_property(_side_edge, "position", Vector2.ZERO, 0.50)
	tween.tween_property(_left_group, "position", _left_group_home, 0.46)
	tween.tween_property(_footer, "position:y", _page_size.y - _footer_height, 0.42)


func close_dialogue() -> void:
	if not visible or _closing:
		return
	_closing = true
	closing.emit()
	var tween := _new_transition(Tween.EASE_IN)
	tween.tween_property(_backdrop, "color", Color(0.025, 0.02, 0.04, 0.0), 0.34)
	tween.tween_property(_page, "modulate", Color(1, 1, 1, 0), 0.32)
	tween.tween_property(_sidebar, "position", Vector2(-_sidebar_shift, 0.0), 0.34)
	tween.tween_property(_side_edge, "position", Vector2(-_sidebar_shift, 0.0), 0.34)
	tween.tween_property(
		_left_group, "position", Vector2(_left_group_home.x - _sidebar_shift, 0.0), 0.32
	)
	tween.tween_property(_footer, "position:y", _page_size.y, 0.32)
	tween.finished.connect(_finish_close)


func move_selection(step: int) -> void:
	if not visible or _closing:
		return
	_selected = posmod(_selected + step, OPTION_NAMES.size())
	_refresh_options()


func activate_selected() -> void:
	if not visible or _closing:
		return
	if _selected == 0:
		gameplay_requested.emit()
		close_dialogue()
		return
	if _selected == OPTION_NAMES.size() - 1:
		close_dialogue()
		return
	_notice.text = "COMING SOON  ·  AKTIVITAS INI SEGERA HADIR"


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "WorldDimmer"
	_backdrop.color = Color(0.025, 0.02, 0.04, 0.0)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_page = Control.new()
	_page.name = "FullScreenMenu"
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_page.modulate = Color(1, 1, 1, 0)
	add_child(_page)

	_sidebar = Polygon2D.new()
	_sidebar.name = "AngularSidebar"
	_sidebar.color = Color(INK.r, INK.g, INK.b, 0.94)
	_page.add_child(_sidebar)
	_side_edge = Polygon2D.new()
	_side_edge.name = "GoldSidebarEdge"
	_side_edge.color = GOLD
	_page.add_child(_side_edge)

	_footer = ColorRect.new()
	_footer.name = "ControlFooter"
	_footer.color = Color(INK.r, INK.g, INK.b, 0.82)
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(_footer)

	_message_panel = Panel.new()
	_message_panel.name = "ConversationCaption"
	_message_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_panel.add_theme_stylebox_override(
		"panel", _box(Color(INK.r, INK.g, INK.b, 0.70), Color(1.0, 1.0, 1.0, 0.22), 1)
	)
	_page.add_child(_message_panel)

	_left_group = Control.new()
	_left_group.name = "MenuChoices"
	_left_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.add_child(_left_group)
	_build_left_menu()

	_stage_label = _label("MIRA  /  PENJAGA PADANG", 13, PAPER)
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_add_text_shadow(_stage_label)
	_page.add_child(_stage_label)
	_message = _label("Hai, penjelajah. Mau melihat apa?", 16, PAPER)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_text_shadow(_message)
	_page.add_child(_message)
	_notice = _label("PILIH AKTIVITAS UNTUK MULAI", 12, GOLD)
	_page.add_child(_notice)
	_footer_left = _label("↑ ↓ PILIH     ENTER / TAP BUKA", 12, PAPER)
	_page.add_child(_footer_left)
	_footer_right = _label("E / ESC  ·  KEMBALI", 12, PAPER)
	_footer_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_page.add_child(_footer_right)
	_layout()


func _build_left_menu() -> void:
	_brand = _label("PADANG", 36, PAPER)
	_left_group.add_child(_brand)
	_speaker = _label("SOCIAL LINK  /  MIRA", 12, GOLD)
	_left_group.add_child(_speaker)
	_title = _label("MIRA", 21, PAPER)
	_left_group.add_child(_title)
	_subheading = _label("PENJAGA PADANG", 13, Color("c2bbc8"))
	_left_group.add_child(_subheading)
	for index in OPTION_NAMES.size():
		_add_option(index)


func _add_option(index: int) -> void:
	var button := Button.new()
	button.name = "Choice_%02d" % (index + 1)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var contents := HBoxContainer.new()
	contents.name = "ChoiceContents"
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contents.offset_left = 12
	contents.offset_right = -10
	contents.add_theme_constant_override("separation", 8)
	button.add_child(contents)
	var label := _label("%02d  %s" % [index + 1, OPTION_NAMES[index]], 15, PAPER)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_child(label)
	var hint_text := "KELUAR" if index == OPTION_NAMES.size() - 1 \
		else ("PILIH" if index == 0 else "COMING SOON")
	var hint := _label(hint_text, 10, GOLD)
	contents.add_child(hint)
	button.pressed.connect(_on_option_pressed.bind(index))
	_left_group.add_child(button)
	_options.append(button)
	_option_labels.append(label)
	_option_hints.append(hint)


func _layout() -> void:
	if _page == null:
		return
	var viewport_size := get_viewport_rect().size
	_compact = viewport_size.x < 760.0 or viewport_size.y < 460.0
	_portrait_layout = viewport_size.y > viewport_size.x
	_page.offset_left = 0.0
	_page.offset_top = 0.0
	_page.offset_right = 0.0
	_page.offset_bottom = 0.0
	_page_size = viewport_size

	var side_top := 0.43 if not _compact else 0.47
	var side_bottom := 0.28 if not _compact else 0.36
	if _portrait_layout:
		side_top = 0.78
		side_bottom = 0.62
	_sidebar.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(_page_size.x * side_top, 0.0),
		Vector2(_page_size.x * side_bottom, _page_size.y),
		Vector2(0.0, _page_size.y),
	])
	_side_edge.polygon = PackedVector2Array([
		Vector2(_page_size.x * (side_top - 0.010), 0.0),
		Vector2(_page_size.x * side_top, 0.0),
		Vector2(_page_size.x * (side_bottom + 0.010), _page_size.y),
		Vector2(_page_size.x * side_bottom, _page_size.y),
	])

	_footer_height = 48.0 if _compact else 58.0
	_footer.position = Vector2(0.0, _page_size.y - _footer_height)
	_footer.size = Vector2(_page_size.x, _footer_height)
	var content_x := 20.0 if _compact else 38.0
	var content_width := maxf(_page_size.x * side_bottom - content_x - 20.0, 112.0)
	if _portrait_layout:
		content_x = 16.0
		content_width = maxf(_page_size.x * side_bottom - content_x - 18.0, 128.0)
	_left_group_home = Vector2(content_x, 0.0)
	_left_group.position = _left_group_home
	_left_group.size = Vector2(content_width, _page_size.y)
	var header_y := 16.0 if _compact else 26.0
	_brand.position = Vector2(0.0, header_y)
	_brand.size = Vector2(content_width, 34.0 if _compact else 42.0)
	_brand.add_theme_font_size_override("font_size", 27 if _compact else 36)
	_speaker.position = Vector2(0.0, header_y + (30.0 if _compact else 40.0))
	_speaker.size = Vector2(content_width, 18.0)
	_speaker.add_theme_font_size_override("font_size", 10 if _compact else 12)
	_title.position = Vector2(0.0, header_y + (49.0 if _compact else 63.0))
	_title.size = Vector2(content_width, 30.0 if _compact else 36.0)
	_title.add_theme_font_size_override("font_size", 18 if _compact else 21)
	_subheading.position = Vector2(0.0, header_y + 101.0)
	_subheading.size = Vector2(content_width, 20.0)
	_subheading.visible = not _compact

	var row_height := 38.0 if _compact else 50.0
	var row_gap := 6.0 if _compact else 9.0
	var menu_height := row_height * OPTION_NAMES.size() + row_gap * (OPTION_NAMES.size() - 1)
	var minimum_menu_y := header_y + (88.0 if _compact else 174.0)
	var maximum_menu_y := _page_size.y - _footer_height - menu_height - 12.0
	var menu_y := minf(minimum_menu_y, maximum_menu_y)
	menu_y = maxf(menu_y, header_y + (82.0 if _compact else 160.0))
	for index in _options.size():
		_options[index].position = Vector2(0.0, menu_y + float(index) * (row_height + row_gap))
		_options[index].size = Vector2(content_width, row_height)
		_options[index].custom_minimum_size = Vector2(0.0, row_height)
		_option_labels[index].add_theme_font_size_override("font_size", 12 if _compact else 15)
		_option_hints[index].visible = not _compact

	var message_x := _page_size.x * (side_bottom + 0.045)
	var message_width := minf(_page_size.x * 0.34, _page_size.x - message_x - 20.0)
	_message_panel.position = Vector2(message_x, _page_size.y - _footer_height - 66.0)
	_message_panel.size = Vector2(maxf(message_width, 140.0), 48.0)
	_message.position = _message_panel.position + Vector2(12.0, 3.0)
	_message.size = _message_panel.size - Vector2(24.0, 6.0)
	_message.add_theme_font_size_override("font_size", 13 if _compact else 16)
	var label_left := side_top + 0.02
	if _portrait_layout:
		label_left = side_bottom + 0.035
	_stage_label.position = Vector2(_page_size.x * label_left, header_y)
	_stage_label.size = Vector2(maxf(_page_size.x * (1.0 - label_left) - 24.0, 100.0), 20.0)
	_stage_label.add_theme_font_size_override("font_size", 10 if _compact else 13)
	var footer_y := _page_size.y - _footer_height
	_footer_left.position = Vector2(18.0, footer_y + 4.0)
	_footer_left.size = Vector2(_page_size.x * 0.32, _footer_height - 8.0)
	_footer_left.add_theme_font_size_override("font_size", 10 if _compact else 12)
	_notice.position = Vector2(_page_size.x * 0.39, footer_y + 4.0)
	_notice.size = Vector2(_page_size.x * 0.35, _footer_height - 8.0)
	_notice.add_theme_font_size_override("font_size", 10 if _compact else 12)
	_footer_right.position = Vector2(_page_size.x * 0.72, footer_y + 4.0)
	_footer_right.size = Vector2(_page_size.x * 0.26 - 18.0, _footer_height - 8.0)
	_footer_right.add_theme_font_size_override("font_size", 10 if _compact else 12)
	_sidebar_shift = _page_size.x * (side_top + 0.06)


func _set_open_pose() -> void:
	_sidebar.position = Vector2(-_sidebar_shift, 0.0)
	_side_edge.position = _sidebar.position
	_left_group.position = Vector2(_left_group_home.x - _sidebar_shift, 0.0)
	_footer.position.y = _page_size.y
	_page.modulate = Color(1, 1, 1, 0)
	_backdrop.color = Color(0.025, 0.02, 0.04, 0.0)


func _new_transition(ease: int) -> Tween:
	if _transition != null and _transition.is_running():
		_transition.kill()
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_CUBIC).set_ease(ease)
	return _transition


func _refresh_options() -> void:
	for index in _options.size():
		var selected := index == _selected
		var returning := index == OPTION_NAMES.size() - 1
		var fill := (
			RED if returning and selected else (GOLD if selected else Color(0.0, 0.0, 0.0, 0.18))
		)
		var border := GOLD if selected else Color(1.0, 1.0, 1.0, 0.32)
		var normal := _box(fill, border, 2 if selected else 1)
		var hover := _box(Color("d9a629") if selected else Color("40394a"), GOLD, 2)
		_options[index].add_theme_stylebox_override("normal", normal)
		_options[index].add_theme_stylebox_override("hover", hover)
		_options[index].add_theme_stylebox_override("pressed", hover)
		_option_labels[index].add_theme_color_override("font_color", INK if selected else PAPER)
		_option_hints[index].add_theme_color_override(
			"font_color", PAPER if selected and returning else (INK if selected else GOLD)
		)


func _on_option_pressed(index: int) -> void:
	_selected = index
	_refresh_options()
	activate_selected()


func _finish_close() -> void:
	visible = false
	_closing = false
	closed.emit()


func _add_text_shadow(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.72))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(0)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style
