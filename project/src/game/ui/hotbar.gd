extends Control
## Hotbar kotak bawah ala Minecraft: 5 slot, tengah berisi Buku Sihir.
## Bersih, pixel, tanpa gradient AI slop.

signal slot_selected(index: int, item_id: String)

const SLOT_COUNT := 5
const SLOT_SIZE := 52.0
const BAR_PAD := 6.0

var items: Array[String] = ["", "", "spell_book", "", ""]
var selected := 2

var _bar: PanelContainer
var _row: HBoxContainer
var _slots: Array[Button] = []


func _ready() -> void:
	name = "Hotbar"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_build_bar()
	_refresh()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _build_bar() -> void:
	_bar = PanelContainer.new()
	_bar.name = "Bar"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("c6c6c6")
	style.border_color = Color("373737")
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = BAR_PAD
	style.content_margin_right = BAR_PAD
	style.content_margin_top = BAR_PAD
	style.content_margin_bottom = BAR_PAD
	_bar.add_theme_stylebox_override("panel", style)
	add_child(_bar)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 4)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_bar.add_child(_row)
	for i in SLOT_COUNT:
		var btn := Button.new()
		btn.name = "Slot%d" % i
		btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.pressed.connect(_on_slot_pressed.bind(i))
		_row.add_child(btn)
		_slots.append(btn)


func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var bar_w := SLOT_COUNT * SLOT_SIZE + (SLOT_COUNT - 1) * 4 + BAR_PAD * 2
	var bar_h := SLOT_SIZE + BAR_PAD * 2
	size = Vector2(bar_w, bar_h)
	position = Vector2((vp.x - bar_w) * 0.5, vp.y - bar_h - 16)


func refresh() -> void:
	_refresh()


func _refresh() -> void:
	for i in _slots.size():
		var btn := _slots[i]
		var item := items[i] if i < items.size() else ""
		var is_sel := i == selected
		_apply_slot_style(btn, is_sel)
		_apply_slot_icon(btn, item, is_sel)


func _apply_slot_style(btn: Button, is_sel: bool) -> void:
	var bg := StyleBoxFlat.new()
	bg.set_corner_radius_all(4)
	bg.content_margin_left = 4
	bg.content_margin_right = 4
	bg.content_margin_top = 4
	bg.content_margin_bottom = 4
	if is_sel:
		bg.bg_color = Color("e8e8e8")
		bg.border_color = Color("ffffff")
		bg.set_border_width_all(2)
	else:
		bg.bg_color = Color("8b8b8b")
		bg.border_color = Color("5a5a5a")
		bg.set_border_width_all(1)
	btn.add_theme_stylebox_override("normal", bg)
	var hover := bg.duplicate() as StyleBoxFlat
	hover.bg_color = bg.bg_color.lightened(0.06)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _apply_slot_icon(btn: Button, item: String, is_sel: bool) -> void:
	# Bersihkan anak lama.
	for child in btn.get_children():
		child.queue_free()
	btn.text = ""
	if item == "spell_book":
		var icon := TextureRect.new()
		icon.texture = load("res://src/game/ui/book.svg")
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(28, 28)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.modulate = Color("3a2d1a") if not is_sel else Color("1a1208")
		btn.add_child(icon)
		# Label kecil di bawah ikon.
		var lbl := Label.new()
		lbl.text = "BUKU"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 7)
		lbl.add_theme_color_override("font_color", Color("1a1208"))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Pakai container vertikal sederhana via manual offset.
		var wrap := VBoxContainer.new()
		wrap.alignment = BoxContainer.ALIGNMENT_CENTER
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.add_child(wrap)
		wrap.add_child(icon)
		wrap.add_child(lbl)
	elif item == "":
		var dot := Label.new()
		dot.text = "%d" % (btn.get_index() + 1)
		dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dot.add_theme_font_size_override("font_size", 9)
		dot.add_theme_color_override("font_color", Color("373737", 0.55))
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.add_child(dot)
	# Nomor slot kecil di pojok kiri atas.
	var num := Label.new()
	num.text = str(btn.get_index() + 1)
	num.add_theme_font_size_override("font_size", 8)
	num.add_theme_color_override("font_color", Color("f0f0f0", 0.85))
	num.position = Vector2(4, 2)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(num)
	if is_sel:
		var sel := Panel.new()
		sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sel.offset_left = -2
		sel.offset_top = -2
		sel.offset_right = 2
		sel.offset_bottom = 2
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0, 0, 0, 0)
		s.border_color = Color("f2bd35")
		s.set_border_width_all(2)
		s.set_corner_radius_all(6)
		sel.add_theme_stylebox_override("panel", s)
		btn.add_child(sel)
		sel.z_index = 10


func _on_slot_pressed(index: int) -> void:
	selected = clampi(index, 0, SLOT_COUNT - 1)
	_refresh()
	var item := ""
	if index < items.size():
		item = items[index]
	slot_selected.emit(index, item)


func get_selected_item() -> String:
	if selected < 0 or selected >= items.size():
		return ""
	return items[selected]


func set_items(next: Array[String]) -> void:
	items = next.duplicate()
	if selected >= items.size():
		selected = 0
	_refresh()
