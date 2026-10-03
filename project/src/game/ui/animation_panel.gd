extends Control
## Katalog animasi: SEMUA klip (UAL1 + UAL2) bisa dipilih dan diputar di mannequin.
## Ada mode "putar semua" yang menelusuri seluruh klip satu per satu seperti reel.

signal closed
signal clip_selected(clip: String)

const Catalog = preload("res://src/game/animation/catalog.gd")
const Character = preload("res://src/game/mannequin.gd")
const PANEL_COLOR := Color(0.035, 0.04, 0.06, 0.94)
const ROW_COLOR := Color(0.15, 0.14, 0.24)
const ROW_ACTIVE := Color(0.36, 0.28, 0.56)
const TEXT_COLOR := Color("e9e4f7")
const DIM_COLOR := Color("9d98b5")
const REEL_HOLD := 1.6
## Jendela kecil di tengah layar, bukan fullscreen: daftar 86 klip cukup discroll.
const WINDOW_MAX := Vector2(620, 520)
const WINDOW_RATIO := Vector2(0.90, 0.78)

var character: Character
var _backdrop: ColorRect
var _window: PanelContainer
var _rows: Dictionary[String, Button] = {}
var _order: PackedStringArray = PackedStringArray()
var _status: Label
var _detail: Label
var _reel_button: Button
var _repeat_button: Button
var _slow_button: Button
var _scroll: ScrollContainer
var _list: VBoxContainer
var _ignore_touch_until := 0
## Scroll ditangani sendiri: ScrollContainer bawaan tidak menerima drag saat
## jari mendarat di atas tombol baris, dan itulah keluhan "scroll susah, harus
## dari pojok". Di sini drag dari titik mana pun di daftar selalu menggeser.
var _drag_finger := -1
var _drag_from_y := 0.0
var _drag_start_scroll := 0.0
var _drag_travelled := 0.0
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
	get_viewport().size_changed.connect(_resize_window)


func _build() -> void:
	# Latar gelap transparan; sentuh di luarnya = tutup (tidak memakai layar penuh
	# sebagai panel, jadi game tetap kelihatan di belakang).
	_backdrop = ColorRect.new()
	_backdrop.name = "PanelBackdrop"
	_backdrop.color = Color(0.02, 0.02, 0.04, 0.55)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.gui_input.connect(_backdrop_input)
	_window = PanelContainer.new()
	_window.name = "AnimationWindow"
	var frame := StyleBoxFlat.new()
	frame.bg_color = PANEL_COLOR
	frame.border_color = Color(1, 1, 1, 0.14)
	frame.set_border_width_all(1)
	frame.set_corner_radius_all(24)
	_window.add_theme_stylebox_override("panel", frame)
	add_child(_window)
	_resize_window()
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_window.add_child(margin)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	column.add_child(_title())
	column.add_child(_toolbar())
	_status = _label("", 18, TEXT_COLOR)
	column.add_child(_status)
	_detail = _label("", 16, DIM_COLOR)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_detail)
	_scroll = ScrollContainer.new()
	_scroll.name = "ClipScroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
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
	_repeat_button = _button("ULANGI", _toggle_repeat)
	_slow_button = _button("1×", _toggle_slow)
	row.add_child(_reel_button)
	row.add_child(_repeat_button)
	row.add_child(_slow_button)
	var close := _button("TUTUP", close_panel)
	close.custom_minimum_size = Vector2(120, 48)
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
	button.custom_minimum_size = Vector2(140, 48)
	button.add_theme_font_size_override("font_size", 18)
	var style := StyleBoxFlat.new()
	style.bg_color = ROW_COLOR
	# Pil penuh (radius = setengah tinggi) supaya tidak ada sudut kotak.
	style.set_corner_radius_all(26)
	style.content_margin_left = 14
	style.content_margin_right = 14
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
	button.clip_text = true
	button.custom_minimum_size = Vector2(0, 54)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Baris hanya tampilan: sentuhan diatur panel supaya drag = scroll dan
	# ketukan pendek = pilih klip, tanpa saling makan.
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows[clip] = button
	return button


func contains_point(point: Vector2) -> bool:
	var local := get_global_transform_with_canvas().affine_inverse() * point
	return Rect2(Vector2.ZERO, size).has_point(local)


func list_rect() -> Rect2:
	if _scroll == null:
		return Rect2()
	return Rect2(_scroll.global_position, _scroll.size)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _drag_finger == -1 and list_rect().has_point(touch.position):
			_drag_finger = touch.index
			_drag_from_y = touch.position.y
			_drag_start_scroll = float(_scroll.scroll_vertical)
			_drag_travelled = 0.0
		elif not touch.pressed and touch.index == _drag_finger:
			var tapped := _drag_travelled < 14.0
			_drag_finger = -1
			if tapped:
				_select_row_at(touch.position)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _drag_finger:
			return
		var offset := _drag_from_y - drag.position.y
		_drag_travelled = maxf(_drag_travelled, absf(offset))
		_scroll.scroll_vertical = int(_drag_start_scroll + offset)


func _select_row_at(point: Vector2) -> void:
	if not list_rect().has_point(point):
		return
	for clip: String in _rows:
		var row := _rows[clip]
		if row.visible and row.get_global_rect().has_point(point):
			_select(clip, false)
			return


func _resize_window() -> void:
	if _window == null:
		return
	var view := get_viewport_rect().size
	var target := Vector2(minf(WINDOW_MAX.x, view.x * WINDOW_RATIO.x),
		minf(WINDOW_MAX.y, view.y * WINDOW_RATIO.y))
	_window.custom_minimum_size = target
	_window.size = target
	_window.position = (view - target) * 0.5


func _backdrop_input(event: InputEvent) -> void:
	# Hanya sentuhan jari (bukan mouse emulasi) yang menutup, dan tidak dari event
	# yang baru saja membuka panel. Tanpa ini, satu ketukan pada tombol ANIM
	# membuka lalu langsung menutup panelnya sendiri.
	if not (event is InputEventScreenTouch):
		return
	var touch := event as InputEventScreenTouch
	if not touch.pressed or touch.canceled:
		return
	if Time.get_ticks_msec() < _ignore_touch_until:
		return
	close_panel()


func window_rect() -> Rect2:
	if _window == null:
		return Rect2()
	return Rect2(_window.global_position, _window.size)


func open() -> void:
	visible = true
	_ignore_touch_until = Time.get_ticks_msec() + 250
	_resize_window()
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
	_repeat_button.text = "ULANGI" if _repeat else "SEKALI"


func _toggle_slow() -> void:
	_slow = not _slow
	_slow_button.text = "0,5×" if _slow else "1×"
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
		style.set_corner_radius_all(26)
		style.content_margin_left = 14
		style.content_margin_right = 14
		_rows[clip].add_theme_stylebox_override("normal", style)
	_detail.text = "%s — %s\nGeser di daftar untuk scroll; ketuk luar jendela untuk tutup." % [
		character.current_label(), character.description_of(character.clip)]


func _process(delta: float) -> void:
	if not visible or character == null:
		return
	_report()
	if not _reel:
		return
	if character.mode == Character.Mode.ACTION:
		return # Tunggu klip sekali jalan selesai; avatar kembali sendiri.
	if character.mode == Character.Mode.HELD:
		_reel_timer = maxf(_reel_timer, REEL_HOLD)
	_reel_timer -= delta
	if _reel_timer > 0.0:
		return
	if character.mode == Character.Mode.SHOWCASE and Catalog.is_loop(character.clip):
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
