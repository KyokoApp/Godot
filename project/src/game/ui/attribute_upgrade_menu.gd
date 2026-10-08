extends Control
## Panel peningkatan meta yang dibuka dari opsi UPGRADE ATRIBUT NPC.

signal closed

const PAPER := Color("#f2edf8")
const GOLD := Color("#efd18a")
const MUTED := Color("#b3afc1")
const VIOLET := Color("#a98af4")

var meta_progress: Object
var _backdrop: ColorRect
var _panel: PanelContainer
var _title: Label
var _coins_label: Label
var _grid: GridContainer
var _scroll: ScrollContainer
var _transition: Tween
var _closing := false


func _ready() -> void:
	name = "AttributeUpgradeMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()


func open() -> void:
	if _closing or not is_instance_valid(meta_progress):
		return
	_refresh()
	visible = true
	_closing = false
	_backdrop.color = Color(0.015, 0.012, 0.028, 0.0)
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.97, 0.97)
	_panel.pivot_offset = _panel.size * 0.5
	var tween := _new_transition(Tween.EASE_OUT)
	tween.tween_property(_backdrop, "color:a", 0.84, 0.24)
	tween.tween_property(_panel, "modulate:a", 1.0, 0.30)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.34)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	var tween := _new_transition(Tween.EASE_IN_OUT)
	tween.tween_property(_backdrop, "color:a", 0.0, 0.20)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.20)
	tween.tween_property(_panel, "scale", Vector2(0.985, 0.985), 0.20)
	tween.finished.connect(_finish_close)


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "UpgradeBackdrop"
	_backdrop.color = Color(0.015, 0.012, 0.028, 0.0)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_panel = PanelContainer.new()
	_panel.name = "UpgradePanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style(
		Color(0.035, 0.036, 0.060, 0.99), Color(0.58, 0.45, 0.84, 0.82), 16))
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 12)
	_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_constant_override("separation", 0)
	header.add_child(heading)
	_title = _label("UPGRADE ATRIBUT", 19, PAPER)
	heading.add_child(_title)
	var subtitle := _label("Peningkatan kecil, permanen untuk run berikutnya.", 10, MUTED)
	heading.add_child(subtitle)
	_coins_label = _label("KOIN 000", 14, GOLD)
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_coins_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_coins_label)
	var close_button := _button("TUTUP", 90, close)
	close_button.name = "CloseUpgradeMenu"
	header.add_child(close_button)

	_scroll = ScrollContainer.new()
	_scroll.name = "UpgradeScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	content.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.name = "UpgradeGrid"
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 8)
	_scroll.add_child(_grid)
	var footer := _label("Koin dari zombie. Harga naik bertahap; level atribut terbatas.",
		10, MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(footer)


func _layout() -> void:
	if not is_instance_valid(_panel):
		return
	var viewport := get_viewport_rect().size
	var width := minf(940.0, maxf(270.0, viewport.x - 20.0))
	var height := minf(700.0, maxf(300.0, viewport.y - 20.0))
	_panel.size = Vector2(width, height)
	_panel.position = (viewport - _panel.size) * 0.5
	_panel.pivot_offset = _panel.size * 0.5
	_grid.columns = 1 if viewport.x < 560.0 else 2


func _refresh() -> void:
	if not is_instance_valid(meta_progress):
		return
	_coins_label.text = "KOIN %06d" % int(meta_progress.get("coins"))
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for info: Dictionary in meta_progress.call("get_upgrades"):
		_grid.add_child(_make_upgrade_card(info))


func _make_upgrade_card(info: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0.0, 118.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _panel_style(
		Color(0.070, 0.071, 0.100, 0.98), Color(0.45, 0.38, 0.62, 0.58), 10))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_bottom", 8)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	margin.add_child(content)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)
	var title := _label(str(info.get("name", "UPGRADE")), 12, PAPER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var maximum := int(info.get("max_level", 1))
	var current := int(info.get("level", 0))
	var level_text := "MAX" if bool(info.get("maxed", false)) \
		else "LV %d/%d" % [current, maximum]
	var level_label := _label(level_text, 10, VIOLET)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(level_label)
	var description := _label(str(info.get("description", "")), 10, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(description)
	var cost := int(info.get("cost", 0))
	var is_maxed := bool(info.get("maxed", false))
	var purchase := _button("MAKSIMUM" if is_maxed else "TINGKATKAN  ·  %d KOIN" % cost,
		42.0, _purchase_upgrade.bind(str(info.get("id", ""))))
	purchase.disabled = is_maxed or int(meta_progress.get("coins")) < cost
	if purchase.disabled:
		purchase.modulate = Color(0.73, 0.73, 0.79, 0.72)
	content.add_child(purchase)
	return card


func _purchase_upgrade(upgrade_id: String) -> void:
	if is_instance_valid(meta_progress) and bool(meta_progress.call("purchase_upgrade", upgrade_id)):
		_refresh()


func _finish_close() -> void:
	visible = false
	_closing = false
	closed.emit()


func _new_transition(ease: int) -> Tween:
	if _transition != null and _transition.is_running():
		_transition.kill()
	_transition = create_tween()
	_transition.set_parallel(true)
	_transition.set_trans(Tween.TRANS_CUBIC).set_ease(ease)
	return _transition


func _button(caption: String, width: float, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(width, 42)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_stylebox_override("normal", _panel_style(
		Color(0.14, 0.12, 0.20, 1.0), Color(0.56, 0.46, 0.77, 0.78), 8))
	button.add_theme_stylebox_override("hover", _panel_style(
		Color(0.24, 0.19, 0.34, 1.0), GOLD, 8))
	button.add_theme_stylebox_override("pressed", _panel_style(
		Color(0.30, 0.22, 0.40, 1.0), GOLD, 8))
	button.pressed.connect(action)
	return button


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style
