extends Control
## Layar kenalan bergaya pop-art: potret karakter di kiri, pilihan aksi di kanan.

signal closed

const Character = preload("res://src/game/mannequin.gd")
const INK := Color("201d29")
const INK_SOFT := Color("302b3a")
const PAPER := Color("f4f0e7")
const PAPER_DARK := Color("e4ded1")
const GOLD := Color("f2bd35")
const RED := Color("d94a42")
const TEXT_DARK := Color("28242d")
const TEXT_MUTED := Color("746e78")
const OPTION_NAMES: Array[String] = [
	"PETUALANGAN",
	"INVENTARIS",
	"STATUS KARAKTER",
	"KEMBALI",
]

var _backdrop: ColorRect
var _card: PanelContainer
var _card_margin: MarginContainer
var _split: HBoxContainer
var _menu_column: VBoxContainer
var _title: Label
var _subheading: Label
var _choices_title: Label
var _option_list: VBoxContainer
var _footer: Label
var _portrait_container: SubViewportContainer
var _portrait: SubViewport
var _portrait_character: Character
var _speaker: Label
var _message: Label
var _notice: Label
var _options: Array[Button] = []
var _option_labels: Array[Label] = []
var _option_hints: Array[Label] = []
var _selected := 0
var _closing := false
var _card_left := 0.0
var _card_right := 0.0


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
	_ensure_portrait()
	_speaker.text = character_name.to_upper() + "  /  KENALAN BARU"
	_message.text = "Hai, penjelajah. Mau melihat apa?"
	_notice.text = "Pilih aktivitas — fitur permainan segera hadir."
	_selected = 0
	_refresh_options()
	visible = true
	_closing = false
	_backdrop.color = Color(0.025, 0.02, 0.04, 0.0)
	_card.modulate = Color(1, 1, 1, 0.0)
	_card.offset_left = _card_left + 40.0
	_card.offset_right = _card_right + 40.0
	_portrait.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_backdrop, "color", Color(0.025, 0.02, 0.04, 0.78), 0.28)
	tween.tween_property(_card, "modulate", Color.WHITE, 0.32)
	tween.tween_property(_card, "offset_left", _card_left, 0.42)
	tween.tween_property(_card, "offset_right", _card_right, 0.42)


func close_dialogue() -> void:
	if not visible or _closing:
		return
	_closing = true
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_backdrop, "color", Color(0.025, 0.02, 0.04, 0.0), 0.20)
	tween.tween_property(_card, "modulate", Color(1, 1, 1, 0), 0.18)
	tween.tween_property(_card, "offset_left", _card_left + 28.0, 0.22)
	tween.tween_property(_card, "offset_right", _card_right + 28.0, 0.22)
	tween.finished.connect(_finish_close)


func move_selection(step: int) -> void:
	if not visible or _closing:
		return
	_selected = posmod(_selected + step, OPTION_NAMES.size())
	_refresh_options()


func activate_selected() -> void:
	if not visible or _closing:
		return
	if _selected == OPTION_NAMES.size() - 1:
		close_dialogue()
		return
	_notice.text = "COMING SOON  ·  Aktivitas ini akan segera tersedia."
	if not _notice.visible:
		_message.text = _notice.text


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "PersonaBackdrop"
	_backdrop.color = Color(0.025, 0.02, 0.04, 0.78)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_card = PanelContainer.new()
	_card.name = "InteractionCard"
	var frame := _box(PAPER, INK, 2, 16)
	_card.add_theme_stylebox_override("panel", frame)
	_card.anchor_left = 0.035
	_card.anchor_top = 0.055
	_card.anchor_right = 0.965
	_card.anchor_bottom = 0.945
	_card.offset_left = 0.0
	_card.offset_top = 0.0
	_card.offset_right = 0.0
	_card.offset_bottom = 0.0
	_card_left = _card.offset_left
	_card_right = _card.offset_right
	add_child(_card)
	_add_accents()

	_card_margin = MarginContainer.new()
	_card_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_margin.add_theme_constant_override("margin_left", 22)
	_card_margin.add_theme_constant_override("margin_right", 22)
	_card_margin.add_theme_constant_override("margin_top", 18)
	_card_margin.add_theme_constant_override("margin_bottom", 18)
	_card.add_child(_card_margin)
	_split = HBoxContainer.new()
	_split.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_split.add_theme_constant_override("separation", 20)
	_card_margin.add_child(_split)
	_build_portrait_panel(_split)
	_build_menu(_split)
	_layout()


func _add_accents() -> void:
	# Dua bidang miring memberi energi pop-art tanpa menutupi permainan.
	var stripe := ColorRect.new()
	stripe.color = GOLD
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.size = Vector2(8, 138)
	stripe.position = Vector2(4, 42)
	stripe.rotation_degrees = -12.0
	_card.add_child(stripe)
	var red_tab := ColorRect.new()
	red_tab.color = RED
	red_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	red_tab.size = Vector2(66, 8)
	red_tab.anchor_left = 1.0
	red_tab.anchor_right = 1.0
	red_tab.offset_left = -92
	red_tab.offset_right = -20
	red_tab.offset_top = 4
	red_tab.offset_bottom = 12
	_card.add_child(red_tab)


func _build_portrait_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.name = "CharacterPortrait"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.88
	panel.custom_minimum_size = Vector2(150, 0)
	panel.add_theme_stylebox_override("panel", _box(INK, GOLD, 3, 12))
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var tag := _label("SOCIAL LINK   /   01", 13, GOLD)
	column.add_child(tag)
	_portrait_container = SubViewportContainer.new()
	_portrait_container.name = "PortraitViewport"
	_portrait_container.stretch = true
	_portrait_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portrait_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_portrait_container.custom_minimum_size = Vector2(120, 220)
	column.add_child(_portrait_container)
	var caption := _label("MIRA", 25, PAPER)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	var caption_sub := _label("PENJAGA PADANG", 12, Color("b8b1c0"))
	caption_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption_sub)


func _build_menu(parent: HBoxContainer) -> void:
	_menu_column = VBoxContainer.new()
	_menu_column.name = "GameplayChoices"
	_menu_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu_column.size_flags_stretch_ratio = 1.12
	_menu_column.add_theme_constant_override("separation", 10)
	parent.add_child(_menu_column)
	_speaker = _label("INTERAKSI   /   PADANG", 13, Color("a06920"))
	_menu_column.add_child(_speaker)
	_title = _label("Mira", 36, TEXT_DARK)
	_title.add_theme_font_size_override("font_size", 36)
	_menu_column.add_child(_title)
	_subheading = _label("Satu kenalan baru di pulau ini.", 15, TEXT_MUTED)
	_menu_column.add_child(_subheading)

	var message_card := PanelContainer.new()
	message_card.add_theme_stylebox_override("panel", _box(PAPER_DARK, Color("d5cdbc"), 1, 8))
	_menu_column.add_child(message_card)
	var message_margin := MarginContainer.new()
	message_margin.add_theme_constant_override("margin_left", 13)
	message_margin.add_theme_constant_override("margin_right", 13)
	message_margin.add_theme_constant_override("margin_top", 8)
	message_margin.add_theme_constant_override("margin_bottom", 8)
	message_card.add_child(message_margin)
	_message = _label("Hai, penjelajah. Mau melihat apa?", 16, TEXT_DARK)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_margin.add_child(_message)

	_choices_title = _label("PILIHAN", 13, TEXT_MUTED)
	_choices_title.add_theme_constant_override("margin_top", 4)
	_menu_column.add_child(_choices_title)
	_option_list = VBoxContainer.new()
	_option_list.name = "ChoiceList"
	_option_list.add_theme_constant_override("separation", 7)
	_menu_column.add_child(_option_list)
	for index in OPTION_NAMES.size():
		_add_option(_option_list, index)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu_column.add_child(spacer)
	_notice = _label("Pilih aktivitas — fitur permainan segera hadir.", 13, TEXT_MUTED)
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_menu_column.add_child(_notice)
	_footer = _label("↑ ↓ PILIH     ENTER / TAP PILIH     ESC KEMBALI", 11, Color("8a838c"))
	_menu_column.add_child(_footer)


func _add_option(parent: VBoxContainer, index: int) -> void:
	var button := Button.new()
	button.name = "Choice_%02d" % (index + 1)
	button.custom_minimum_size = Vector2(0, 54)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var contents := HBoxContainer.new()
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	contents.offset_left = 14
	contents.offset_right = -12
	contents.add_theme_constant_override("separation", 8)
	button.add_child(contents)
	var label := _label("%02d  %s" % [index + 1, OPTION_NAMES[index]], 15, PAPER)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_child(label)
	var hint_text := "TUTUP" if index == OPTION_NAMES.size() - 1 else "COMING SOON"
	var hint := _label(hint_text, 10, GOLD)
	contents.add_child(hint)
	button.pressed.connect(_on_option_pressed.bind(index))
	parent.add_child(button)
	_options.append(button)
	_option_labels.append(label)
	_option_hints.append(hint)


func _ensure_portrait() -> void:
	if _portrait != null:
		return
	_portrait = SubViewport.new()
	_portrait.name = "PortraitSubViewport"
	_portrait.own_world_3d = true
	_portrait.size = Vector2i(360, 540)
	_portrait.transparent_bg = false
	_portrait.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_portrait_container.add_child(_portrait)
	var stage := Node3D.new()
	stage.name = "PortraitStage"
	_portrait.add_child(stage)
	var environment := WorldEnvironment.new()
	var world_environment := Environment.new()
	world_environment.background_mode = Environment.BG_COLOR
	world_environment.background_color = Color("211d29")
	world_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.ambient_light_color = Color("d8cbb5")
	world_environment.ambient_light_energy = 0.72
	environment.environment = world_environment
	stage.add_child(environment)
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-24, -28, 0)
	key_light.light_color = Color("ffe1a0")
	key_light.light_energy = 1.3
	stage.add_child(key_light)
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-1.8, 1.0, -1.0)
	fill_light.light_color = Color("b7a6ff")
	fill_light.light_energy = 0.65
	fill_light.omni_range = 5.0
	stage.add_child(fill_light)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.32, -3.45)
	camera.fov = 34.0
	camera.look_at(Vector3(0.0, 0.93, 0.0), Vector3.UP)
	stage.add_child(camera)
	camera.current = true
	_portrait_character = Character.new()
	_portrait_character.name = "MiraPortrait"
	_portrait_character.scale = Vector3.ONE * 1.08
	stage.add_child(_portrait_character)
	_portrait_character.set_locomotion("Idle_FoldArms_Loop", 1.0)
	_apply_portrait_palette()
	_resize_portrait.call_deferred()


func _apply_portrait_palette() -> void:
	if _portrait_character.skin == null:
		return
	var materials: Array[ShaderMaterial] = [_portrait_character.skin.skin]
	var inner := _portrait_character.get("_skin_material") as ShaderMaterial
	if inner != null:
		materials.append(inner)
	for material in materials:
		material.set_shader_parameter("skin_dark", Color("342426"))
		material.set_shader_parameter("skin_light", Color("a76831"))


func _resize_portrait() -> void:
	if _portrait == null or _portrait_container == null:
		return
	var target := _portrait_container.size * 1.5
	_portrait.size = Vector2i(maxi(240, int(target.x)), maxi(360, int(target.y)))


func _layout() -> void:
	if _card == null:
		return
	var viewport_size := get_viewport_rect().size
	var compact := viewport_size.x < 760.0 or viewport_size.y < 460.0
	_card.anchor_left = 0.025 if compact else 0.035
	_card.anchor_right = 0.975 if compact else 0.965
	_card.anchor_top = 0.035 if compact else 0.055
	_card.anchor_bottom = 0.965 if compact else 0.945
	_card.offset_left = 0.0
	_card.offset_top = 0.0
	_card.offset_right = 0.0
	_card.offset_bottom = 0.0
	_card_left = 0.0
	_card_right = 0.0
	var outer_margin := 12 if compact else 22
	_card_margin.add_theme_constant_override("margin_left", outer_margin)
	_card_margin.add_theme_constant_override("margin_right", outer_margin)
	_card_margin.add_theme_constant_override("margin_top", 10 if compact else 18)
	_card_margin.add_theme_constant_override("margin_bottom", 10 if compact else 18)
	_split.add_theme_constant_override("separation", 12 if compact else 20)
	_menu_column.add_theme_constant_override("separation", 5 if compact else 10)
	_speaker.add_theme_font_size_override("font_size", 11 if compact else 13)
	_title.add_theme_font_size_override("font_size", 27 if compact else 36)
	_subheading.visible = not compact
	_choices_title.add_theme_font_size_override("font_size", 11 if compact else 13)
	_option_list.add_theme_constant_override("separation", 5 if compact else 7)
	_notice.visible = not compact
	_footer.visible = not compact
	for button in _options:
		button.custom_minimum_size.y = 42 if compact else 54
	if _portrait != null:
		_resize_portrait()
	if compact:
		_portrait_container.custom_minimum_size = Vector2(105, 155)
	else:
		_portrait_container.custom_minimum_size = Vector2(150, 250)


func _refresh_options() -> void:
	for index in _options.size():
		var selected := index == _selected
		var returning := index == OPTION_NAMES.size() - 1
		var fill := GOLD if selected else INK_SOFT
		var border := RED if returning and selected else (GOLD if selected else Color("5b5360"))
		var normal := _box(fill, border, 2 if selected else 1, 7)
		var hover := _box(Color("d9a629") if selected else Color("40394a"), GOLD, 2, 7)
		_options[index].add_theme_stylebox_override("normal", normal)
		_options[index].add_theme_stylebox_override("hover", hover)
		_options[index].add_theme_stylebox_override("pressed", hover)
		_option_labels[index].add_theme_color_override("font_color", INK if selected else PAPER)
		_option_hints[index].add_theme_color_override(
			"font_color", RED if returning and selected else (INK if selected else GOLD)
		)


func _on_option_pressed(index: int) -> void:
	_selected = index
	_refresh_options()
	activate_selected()


func _finish_close() -> void:
	visible = false
	_closing = false
	_portrait.render_target_update_mode = SubViewport.UPDATE_DISABLED
	closed.emit()


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _box(fill: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
