extends Control
## Buku Sihir: UI rapih kotak bersih, tanpa gradient AI slop.
## Menampilkan pilihan skill yang mengubah warna pet secara smooth.

signal skill_selected(skill_id: String)
signal closed

const SKILLS: Array[Dictionary] = [
	{
		"id": "lightning",
		"name": "HANTAMAN PETIR",
		"desc": "Petir dari langit — ulti ala Eudora. Hantam area 2.8 m, kilau epic.",
		"damage": "182",
		"cooldown": "1.0s",
		"icon": "res://src/game/ui/lightning.svg",
		"accent": Color("ffe074"),
	},
	{
		"id": "fireball",
		"name": "TEMBAKAN API",
		"damage": "48",
		"desc": "Proyektil homing klasik. Jejak api tertinggal di dunia.",
		"cooldown": "0.85s",
		"icon": "res://src/game/ui/flame.svg",
		"accent": Color("ff7a45"),
	},
]

var _panel: PanelContainer
var _cards: Dictionary = {}
var _selected_skill := "lightning"

func _ready() -> void:
	name = "SpellBook"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.62)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_bg_input)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "BookPanel"
	_panel.custom_minimum_size = Vector2(640, 380)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0f0e12")
	style.border_color = Color("f2bd35")
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)
	var title := Label.new()
	title.text = "BUKU SIHIR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("fff4d8"))
	vbox.add_child(title)
	var sub := Label.new()
	sub.text = "Pilih sihir — pet akan berubah warna smooth"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color("cfc6d4"))
	vbox.add_child(sub)
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 1)
	line.color = Color("f2bd35", 0.35)
	vbox.add_child(line)
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 14)
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(grid)
	for skill in SKILLS:
		var card := _build_card(skill)
		grid.add_child(card)
		_cards[str(skill["id"])] = card
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 10)
	vbox.add_child(footer)
	var close := Button.new()
	close.text = "TUTUP"
	close.custom_minimum_size = Vector2(140, 38)
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 12)
	close.add_theme_color_override("font_color", Color("cfc6d4"))
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.14, 0.13, 0.16, 1)
	cs.border_color = Color(1, 1, 1, 0.18)
	cs.set_border_width_all(1)
	cs.set_corner_radius_all(8)
	cs.content_margin_left = 12
	cs.content_margin_right = 12
	cs.content_margin_top = 6
	cs.content_margin_bottom = 6
	close.add_theme_stylebox_override("normal", cs)
	var hs := cs.duplicate() as StyleBoxFlat
	hs.bg_color = Color("2e2b33")
	hs.border_color = Color("f2bd35")
	close.add_theme_stylebox_override("hover", hs)
	close.add_theme_stylebox_override("pressed", hs)
	close.pressed.connect(close_book)
	footer.add_child(close)
	_refresh_cards()


func _build_card(skill: Dictionary) -> Button:
	var btn := Button.new()
	btn.name = "Card_%s" % str(skill["id"])
	btn.custom_minimum_size = Vector2(260, 220)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var skill_id := str(skill["id"])
	btn.pressed.connect(_on_card_pressed.bind(skill_id))
	var wrap := PanelContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(wrap)
	# Style will be set in _refresh_cards.
	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_child(vbox)
	var icon_wrap := PanelContainer.new()
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(1, 1, 1, 0.06)
	icon_style.set_corner_radius_all(10)
	icon_style.content_margin_left = 12
	icon_style.content_margin_right = 12
	icon_style.content_margin_top = 10
	icon_style.content_margin_bottom = 10
	icon_wrap.add_theme_stylebox_override("panel", icon_style)
	vbox.add_child(icon_wrap)
	var icon := TextureRect.new()
	icon.texture = load(str(skill["icon"]))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(42, 42)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_wrap.add_child(icon)
	var name_lbl := Label.new()
	name_lbl.text = str(skill["name"])
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color("fff4d8"))
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)
	var desc := Label.new()
	desc.text = str(skill["desc"])
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(220, 0)
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color("cfc6d4"))
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc)
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 8)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stats)
	var dmg := _stat_chip("DMG %s" % str(skill["damage"]), skill["accent"])
	var cd := _stat_chip("CD %s" % str(skill["cooldown"]), Color("a5a5ff"))
	stats.add_child(dmg)
	stats.add_child(cd)
	# Store skill id for refresh.
	btn.set_meta("skill_id", skill_id)
	btn.set_meta("wrap", wrap)
	return btn


func _stat_chip(text: String, accent: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(accent.r, accent.g, accent.b, 0.14)
	s.border_color = Color(accent.r, accent.g, accent.b, 0.45)
	s.set_border_width_all(1)
	s.set_corner_radius_all(6)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	chip.add_theme_stylebox_override("panel", s)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", accent)
	chip.add_child(lbl)
	return chip


func _refresh_cards() -> void:
	for skill_id in _cards.keys():
		var btn := _cards[skill_id] as Button
		var wrap := btn.get_meta("wrap") as PanelContainer
		var is_sel := str(skill_id) == _selected_skill
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(12)
		style.content_margin_left = 10
		style.content_margin_right = 10
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		if is_sel:
			style.bg_color = Color("2a241f")
			style.border_color = Color("f2bd35")
			style.set_border_width_all(2)
		else:
			style.bg_color = Color(0.13, 0.12, 0.15, 1)
			style.border_color = Color(1, 1, 1, 0.10)
			style.set_border_width_all(1)
		wrap.add_theme_stylebox_override("panel", style)
		# Outline di button sendiri biar hover tidak hilang.
		var empty := StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty)
		btn.add_theme_stylebox_override("hover", empty)
		btn.add_theme_stylebox_override("pressed", empty)
		btn.add_theme_stylebox_override("focus", empty)


func _on_card_pressed(skill_id: String) -> void:
	_selected_skill = skill_id
	_refresh_cards()
	skill_selected.emit(skill_id)
	# Jangan auto-close, biarkan user lihat highlight lalu tutup manual
	# atau tutup otomatis setelah 0.35 dtk biar transisi pet terlihat.
	await get_tree().create_timer(0.28).timeout
	close_book()


func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			close_book()
	if event is InputEventScreenTouch and event.pressed:
		close_book()


func open_book(current_skill: String) -> void:
	_selected_skill = current_skill
	_refresh_cards()
	show()
	# Animasi pop.
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.92, 0.92)
	_panel.modulate = Color(1, 1, 1, 0)
	var t := create_tween()
	t.set_trans(Tween.TRANS_BACK)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(_panel, "scale", Vector2.ONE, 0.28)
	t.parallel().tween_property(_panel, "modulate", Color.WHITE, 0.22)


func close_book() -> void:
	if not visible:
		return
	var t := create_tween()
	t.tween_property(_panel, "scale", Vector2(0.96, 0.96), 0.14)
	t.parallel().tween_property(_panel, "modulate", Color(1, 1, 1, 0), 0.14)
	await t.finished
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE:
			close_book()
			get_viewport().set_input_as_handled()
