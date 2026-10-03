extends Control
## Selector mode ringan setelah opsi Gameplay pada dialog Mira.

signal mode_selected(mode: String)
signal closed

const INK := Color("201d29")
const PAPER := Color("f4f0e7")
const GOLD := Color("f2bd35")
const ACTIVE := Color("557f46")
const MODE_TITLES: Array[String] = ["SURVIVAL", "MODE 02", "MODE 03"]
const MODE_HINTS: Array[String] = [
	"Hadapi zombie dan bertahan selama mungkin.",
	"COMING SOON",
	"COMING SOON",
]

var _backdrop: ColorRect
var _panel: PanelContainer
var _title: Label
var _subtitle: Label
var _cards: Array[Button] = []
var _card_notes: Array[Label] = []
var _status: Label
var _close_button: Button
var _transition: Tween
var _closing := false


func _ready() -> void:
	name = "GameModeSelector"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()
	get_viewport().size_changed.connect(_layout)


func open() -> void:
	if _closing:
		return
	_closing = false
	visible = true
	_status.text = "SURVIVAL SIAP DIMAINKAN"
	_layout()
	_backdrop.color = Color(0.018, 0.022, 0.034, 0.0)
	_panel.modulate = Color(1, 1, 1, 0)
	_panel.scale = Vector2(0.94, 0.94)
	_panel.pivot_offset = _panel.size * 0.5
	for card in _cards:
		card.modulate = Color(1, 1, 1, 0)
		card.scale = Vector2(0.94, 0.94)
	var tween := _new_transition(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(_backdrop, "color", Color(0.018, 0.022, 0.034, 0.70), 0.24)
	tween.tween_property(_panel, "modulate", Color.WHITE, 0.28)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.30)
	for index in _cards.size():
		tween.tween_property(_cards[index], "modulate", Color.WHITE, 0.24).set_delay(0.08 + index * 0.07)
		tween.tween_property(_cards[index], "scale", Vector2.ONE, 0.25).set_delay(0.08 + index * 0.07)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	var tween := _new_transition(Tween.EASE_IN)
	tween.set_parallel(true)
	tween.tween_property(_backdrop, "color", Color(0.018, 0.022, 0.034, 0.0), 0.20)
	tween.tween_property(_panel, "modulate", Color(1, 1, 1, 0), 0.19)
	tween.tween_property(_panel, "scale", Vector2(0.96, 0.96), 0.20)
	tween.chain().tween_callback(_finish_close)


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "ModeDimmer"
	_backdrop.color = Color(0.018, 0.022, 0.034, 0.0)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.name = "ModePanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)
	var content := VBoxContainer.new()
	content.name = "ModeOptions"
	content.add_theme_constant_override("separation", 14)
	_panel.add_child(content)
	_title = _label("PILIH MODE", 27, PAPER)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_title)
	_subtitle = _label("PILIH CARA BERMAIN", 12, GOLD)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_subtitle)
	var cards := HBoxContainer.new()
	cards.name = "ModeCards"
	cards.add_theme_constant_override("separation", 12)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(cards)
	for index in MODE_TITLES.size():
		var card := _make_card(index)
		cards.add_child(card)
		_cards.append(card)
		var notes := card.get_node("CardContent/Hint") as Label
		_card_notes.append(notes)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	content.add_child(footer)
	_status = _label("SURVIVAL SIAP DIMAINKAN", 12, GOLD)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(_status)
	_close_button = Button.new()
	_close_button.name = "BackToDialogue"
	_close_button.text = "KEMBALI"
	_close_button.custom_minimum_size = Vector2(104, 42)
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.add_theme_font_size_override("font_size", 12)
	_close_button.add_theme_color_override("font_color", PAPER)
	_close_button.add_theme_stylebox_override("normal",
		_button_style(Color("302b3a"), Color(1, 1, 1, 0.18)))
	_close_button.add_theme_stylebox_override("hover", _button_style(Color("433b50"), GOLD))
	_close_button.add_theme_stylebox_override("pressed", _button_style(Color("433b50"), GOLD))
	_close_button.pressed.connect(close)
	footer.add_child(_close_button)


func _make_card(index: int) -> Button:
	var card := Button.new()
	card.name = "Mode_%02d" % index
	card.focus_mode = Control.FOCUS_NONE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.custom_minimum_size = Vector2(154, 144)
	var fill := Color(0.14, 0.19, 0.14, 0.98) if index == 0 else Color(0.09, 0.09, 0.12, 0.84)
	var border := Color(ACTIVE.r, ACTIVE.g, ACTIVE.b, 0.95) if index == 0 else Color(1, 1, 1, 0.18)
	card.add_theme_stylebox_override("normal", _button_style(fill, border))
	card.add_theme_stylebox_override("hover", _button_style(
		Color(0.22, 0.30, 0.20, 0.98) if index == 0 else Color(0.18, 0.17, 0.21, 0.96), GOLD))
	card.add_theme_stylebox_override("pressed", _button_style(Color(0.27, 0.35, 0.23, 1.0), GOLD))
	var content := VBoxContainer.new()
	content.name = "CardContent"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 8)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 12
	content.offset_top = 10
	content.offset_right = -12
	content.offset_bottom = -10
	card.add_child(content)
	var index_label := _label("01" if index == 0 else "%02d" % (index + 1), 12, GOLD)
	index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(index_label)
	var title := _label(MODE_TITLES[index], 17, PAPER if index == 0 else Color("b7b2be"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var hint := _label(MODE_HINTS[index], 11, Color("d2ccd8"))
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)
	card.pressed.connect(_select_mode.bind(index))
	return card


func _layout() -> void:
	if _panel == null:
		return
	var view := get_viewport_rect().size
	var panel_width := minf(view.x - 28.0, 740.0)
	var panel_height := minf(view.y - 28.0, 350.0)
	_panel.size = Vector2(maxf(panel_width, 280.0), maxf(panel_height, 250.0))
	_panel.position = (view - _panel.size) * 0.5
	_panel.pivot_offset = _panel.size * 0.5
	var narrow := view.x < 560.0
	for card in _cards:
		card.custom_minimum_size = Vector2(
			maxf((panel_width - 76.0) / 3.0, 78.0) if narrow else 154.0,
			maxf(panel_height * 0.43, 112.0))


func _select_mode(index: int) -> void:
	if _closing:
		return
	if index == 0:
		mode_selected.emit("survival")
		close()
		return
	_status.text = "MODE INI MASIH COMING SOON"
	var card := _cards[index]
	var tween := create_tween()
	tween.tween_property(card, "scale", Vector2(1.045, 1.045), 0.09)
	tween.tween_property(card, "scale", Vector2.ONE, 0.14)
	var notes := _card_notes[index]
	var original := notes.modulate
	notes.modulate = Color(1.0, 0.86, 0.54, 1.0)
	var note_tween := create_tween()
	note_tween.tween_property(notes, "modulate", original, 0.45)


func _input(event: InputEvent) -> void:
	if not visible or _closing:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		close()
		get_viewport().set_input_as_handled()


func _finish_close() -> void:
	visible = false
	_closing = false
	closed.emit()


func _new_transition(ease: int) -> Tween:
	if _transition != null and _transition.is_running():
		_transition.kill()
	_transition = create_tween()
	_transition.set_trans(Tween.TRANS_CUBIC).set_ease(ease)
	return _transition


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(INK.r, INK.g, INK.b, 0.96)
	style.border_color = Color(GOLD.r, GOLD.g, GOLD.b, 0.68)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	return style


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
