extends Control
## Katalog animasi: SEMUA klip (UAL1 + UAL2) bisa dipilih dan diputar di mannequin.
## Ada mode "putar semua" yang menelusuri seluruh klip satu per satu seperti reel.

signal closed
signal clip_selected(clip: String)

const Catalog = preload("res://src/game/animation/catalog.gd")
const Mannequin = preload("res://src/game/mannequin.gd")
const PANEL_COLOR := Color(0.035, 0.04, 0.06, 0.94)
const ROW_COLOR := Color(0.15, 0.14, 0.24)
const ROW_ACTIVE := Color(0.36, 0.28, 0.56)
const TEXT_COLOR := Color("e9e4f7")
const DIM_COLOR := Color("9d98b5")
const REEL_HOLD := 1.6

var character: Mannequin
var _rows: Dictionary[String, Button] = {}
var _order: PackedStringArray = PackedStringArray()
var _status: Label
var _detail: Label
var _reel_button: Button
var _repeat_button: Button
var _slow_button: Button
var _scroll: ScrollContainer
var _list: VBoxContainer
var _reel := false
var _repeat := true
var _slow := false
var _reel_index := 0
var _reel_timer := 0.0


func _ready() -> void:
	name = "AnimationPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = PANEL_COLOR
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	column.add_child(_title())
	column.add_child(_toolbar())
	_status = _label("", 18, TEXT_COLOR)
	column.add_child(_status)
	_detail = _label("", 16, DIM_COLOR)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_populate()


func _title() -> Control:
	var label := _label("KATALOG ANIMASI — %d klip" % Catalog.clip_count(), 26, TEXT_COLOR)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return label


func _toolbar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_reel_button = _button("PUTAR SEMUA", _toggle_reel)
	_repeat_button = _button("ULANGI: NYALA", _toggle_repeat)
	_slow_button = _button("KECEPATAN: 1×", _toggle_slow)
	row.add_child(_reel_button)
	row.add_child(_repeat_button)
	row.add_child(_slow_button)
	var close := _button("TUTUP", close_panel)
	close.custom_minimum_size = Vector2(140, 52)
	row.add_child(close)
	return row


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(210, 52)
	button.add_theme_font_size_override("font_size", 18)
	var style := StyleBoxFlat.new()
	style.bg_color = ROW_COLOR
	style.set_corner_radius_all(12)
	button.add_theme_stylebox_override("normal", style)
	var active := style.duplicate() as StyleBoxFlat
	active.bg_color = ROW_ACTIVE
	button.add_theme_stylebox_override("pressed", active)
	button.add_theme_stylebox_override("hover", active)
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.pressed.connect(action)
	return button


func _populate() -> void:
	for group: Dictionary in Catalog.GROUPS:
		var header := _label(str(group["label"]), 20, Color("bfe6a8"))
		header.custom_minimum_size = Vector2(0, 34)
		_list.add_child(header)
		for item: Array in group["clips"]:
			var clip: String = item[0]
			_list.add_child(_row(clip, str(item[1])))
	_order = Catalog.names()


func _row(clip: String, label: String) -> Button:
	var length := character.length_of(clip) if character != null else 0.0
	var button := _button("%s  ·  %s  ·  %.2f s" % [label, clip, length],
		func() -> void: _select(clip, false))
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 54)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows[clip] = button
	return button


func contains_point(point: Vector2) -> bool:
	var local := get_global_transform_with_canvas().affine_inverse() * point
	return Rect2(Vector2.ZERO, size).has_point(local)


func open() -> void:
	visible = true
	_refresh_active()
	_report()


func close_panel() -> void:
	visible = false
	_reel = false
	_reel_button.text = "PUTAR SEMUA"
	character.set_playback_scale(1.0)
	closed.emit()


func _toggle_reel() -> void:
	_reel = not _reel
	_reel_button.text = "BERHENTI" if _reel else "PUTAR SEMUA"
	if _reel:
		_reel_index = 0
		_reel_timer = 0.0
		_play_index()


func _toggle_repeat() -> void:
	_repeat = not _repeat
	_repeat_button.text = "ULANGI: NYALA" if _repeat else "ULANGI: MATI"


func _toggle_slow() -> void:
	_slow = not _slow
	_slow_button.text = "KECEPATAN: 0,5×" if _slow else "KECEPATAN: 1×"
	character.set_playback_scale(0.5 if _slow else 1.0)


func _select(clip: String, from_reel: bool) -> void:
	if not from_reel:
		_reel = false
		_reel_button.text = "PUTAR SEMUA"
	character.play_showcase(clip)
	_refresh_active()
	# Klip loop ditahan satu siklus penuh; klip sekali ditunggu sampai selesai.
	_reel_timer = maxf(character.length_of(clip), REEL_HOLD) if Catalog.is_loop(clip) else 0.0
	clip_selected.emit(clip)


func _play_index() -> void:
	if _order.is_empty():
		return
	if _reel_index >= _order.size():
		if not _repeat:
			_reel = false
			_reel_button.text = "PUTAR SEMUA"
			return
		_reel_index = 0
	var clip := _order[_reel_index]
	_select(clip, true)
	_scroll_to(clip)


func _scroll_to(clip: String) -> void:
	if _rows.has(clip):
		_scroll.ensure_control_visible(_rows[clip])


func _refresh_active() -> void:
	for clip: String in _rows:
		var selected := clip == character.clip
		var style := StyleBoxFlat.new()
		style.bg_color = ROW_ACTIVE if selected else ROW_COLOR
		style.set_corner_radius_all(12)
		_rows[clip].add_theme_stylebox_override("normal", style)
	_detail.text = "%s — %s" % [character.current_label(),
		character.description_of(character.clip)]


func _process(delta: float) -> void:
	if not visible or character == null:
		return
	_report()
	if not _reel:
		return
	if character.mode == Mannequin.Mode.ACTION:
		return # Tunggu klip sekali jalan selesai; mannequin kembali sendiri.
	if character.mode == Mannequin.Mode.HELD:
		_reel_timer = maxf(_reel_timer, REEL_HOLD)
	_reel_timer -= delta
	if _reel_timer > 0.0:
		return
	if character.mode == Mannequin.Mode.SHOWCASE and Catalog.is_loop(character.clip):
		# Klip loop panjang (mis. 5,2 s) tetap dihormati selama satu siklus.
		_reel_timer = character.length_of(character.clip)
		if _reel_timer > 0.0:
			return
	_reel_index += 1
	_play_index()


func _report() -> void:
	var percent := int(character.progress() * 100.0)
	_status.text = "Sekarang: %s (%s) — %d%%" % [
		character.current_label(), character.clip, percent]
