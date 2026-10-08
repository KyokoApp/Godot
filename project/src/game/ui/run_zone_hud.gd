extends Control
## HUD Run Zone: waktu, jarak, tombol SPEED +1, dan burst kartun Black Flash.

signal speed_pressed

const INK := Color("171722")
const PAPER := Color("f2ecff")
const PURPLE := Color("c69aff")
const BLACK_FLASH_WORDS := Color("ffffff")

var speed_button: Button
var _panel: PanelContainer
var _title: Label
var _detail: Label
var _distance_label: Label
var _flash: ColorRect
var _flash_label: Label
var _flash_slashes: Array[ColorRect] = []
var _flash_tween: Tween
var _label_tween: Tween


func _ready() -> void:
	name = "RunZoneHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_status_panel()
	_build_speed_button()
	_build_black_flash_overlay()
	hide()


func show_intro() -> void:
	_title.text = "RUN ZONE"
	_detail.text = "PERAPAL MENYIAPKAN MANTRA"
	_distance_label.text = "JALUR BATU · 3 PETAK"
	speed_button.hide()
	speed_button.disabled = true
	_clear_black_flash()
	show()


func show_running(elapsed_seconds: float, speed: float, speed_level: int,
		distance_m: float) -> void:
	var total_seconds := maxi(0, floori(elapsed_seconds))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	_title.text = "RUN ZONE"
	_detail.text = "WAKTU %02d:%02d   ·   %.1f m/s" % [minutes, seconds, speed]
	_distance_label.text = "JARAK %04d m" % maxi(0, floori(distance_m))
	speed_button.text = "SPEED +1\n%02d / 20" % speed_level \
		if speed_level < 20 else "SPEED MAX\n20 / 20"
	speed_button.disabled = speed_level >= 20
	speed_button.show()
	show()


func play_black_flash() -> void:
	_clear_black_flash()
	_flash.show()
	_flash.color = Color(0.0, 0.0, 0.0, 0.0)
	_flash_label.text = "BLACK FLASH!"
	_flash_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_flash_label.scale = Vector2(1.5, 1.5)
	_flash_label.show()
	for slash in _flash_slashes:
		slash.modulate = Color(1.0, 1.0, 1.0, 0.0)
		slash.show()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color", Color(1.0, 1.0, 1.0, 0.78), 0.045)
	_flash_tween.tween_property(_flash, "color", Color(0.015, 0.015, 0.02, 0.64), 0.055)
	_flash_tween.tween_property(_flash, "color", Color(1.0, 1.0, 1.0, 0.58), 0.075)
	_flash_tween.tween_property(_flash, "color", Color(0.0, 0.0, 0.0, 0.0), 0.30)
	_flash_tween.finished.connect(_on_flash_finished)
	_label_tween = create_tween()
	_label_tween.set_parallel(true)
	_label_tween.tween_property(_flash_label, "modulate", Color.WHITE, 0.12)
	_label_tween.tween_property(_flash_label, "scale", Vector2.ONE, 0.14)
	for index in range(_flash_slashes.size()):
		var slash := _flash_slashes[index]
		var delay := float(index) * 0.025
		_label_tween.tween_property(slash, "modulate", Color.WHITE, 0.12).set_delay(delay)
	_label_tween.chain().tween_interval(0.38)
	_label_tween.chain().tween_property(_flash_label, "modulate", Color(1, 1, 1, 0), 0.22)


func play_hollow_purple_flash() -> void:
	if _flash_tween != null and _flash_tween.is_running():
		_flash_tween.kill()
	if _label_tween != null and _label_tween.is_running():
		_label_tween.kill()
	_flash_label.hide()
	for slash in _flash_slashes:
		slash.hide()
	_flash.show()
	_flash.color = Color(1.0, 1.0, 1.0, 0.44)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color", Color(1.0, 1.0, 1.0, 0.0), 0.28)
	_flash_tween.finished.connect(_flash.hide)


func _build_status_panel() -> void:
	_panel = PanelContainer.new()
	_panel.name = "RunStatusPanel"
	_panel.position = Vector2(18.0, 18.0)
	_panel.custom_minimum_size = Vector2(290.0, 0.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_panel.add_child(column)
	_title = _label("RUN ZONE", 14, PURPLE)
	_detail = _label("PERAPAL MENYIAPKAN MANTRA", 13, PAPER)
	_distance_label = _label("JALUR BATU · 3 PETAK", 11, Color("c6bfd0"))
	column.add_child(_title)
	column.add_child(_detail)
	column.add_child(_distance_label)


func _build_speed_button() -> void:
	speed_button = Button.new()
	speed_button.name = "RunSpeedPlusOne"
	speed_button.text = "SPEED +1\n00 / 20"
	speed_button.focus_mode = Control.FOCUS_NONE
	speed_button.mouse_filter = Control.MOUSE_FILTER_STOP
	speed_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	speed_button.anchor_left = 1.0
	speed_button.anchor_right = 1.0
	speed_button.anchor_top = 1.0
	speed_button.anchor_bottom = 1.0
	speed_button.offset_left = -176.0
	speed_button.offset_right = -20.0
	speed_button.offset_top = -112.0
	speed_button.offset_bottom = -24.0
	speed_button.add_theme_font_size_override("font_size", 15)
	speed_button.add_theme_color_override("font_color", PAPER)
	speed_button.add_theme_color_override("font_hover_color", Color.WHITE)
	speed_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	speed_button.add_theme_stylebox_override("normal", _speed_style(Color(0.14, 0.08, 0.22, 0.91)))
	speed_button.add_theme_stylebox_override("hover", _speed_style(Color(0.28, 0.12, 0.43, 0.96)))
	speed_button.add_theme_stylebox_override("pressed", _speed_style(Color(0.42, 0.16, 0.65, 1.0)))
	speed_button.add_theme_stylebox_override("disabled", _speed_style(Color(0.10, 0.09, 0.14, 0.74)))
	speed_button.pressed.connect(func() -> void: speed_pressed.emit())
	add_child(speed_button)
	speed_button.hide()
	speed_button.disabled = true


func _build_black_flash_overlay() -> void:
	_flash = ColorRect.new()
	_flash.name = "BlackFlashMonochromePulse"
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(0.0, 0.0, 0.0, 0.0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_flash)
	_flash.hide()
	var slash_colors := [Color.WHITE, Color(0.015, 0.015, 0.02),
		Color(0.68, 0.68, 0.72), Color.WHITE, Color(0.04, 0.04, 0.05)]
	for index in range(slash_colors.size()):
		var slash := ColorRect.new()
		slash.name = "ComicSlash_%02d" % index
		slash.color = slash_colors[index]
		slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slash.anchor_left = 0.5
		slash.anchor_right = 0.5
		slash.anchor_top = 0.5
		slash.anchor_bottom = 0.5
		slash.offset_left = -620.0
		slash.offset_right = 620.0
		var row := float(index - 2)
		slash.offset_top = row * 20.0 - 6.0
		slash.offset_bottom = row * 20.0 + 6.0
		slash.pivot_offset = Vector2(620.0, 6.0)
		slash.rotation = -0.24 + float(index) * 0.11
		add_child(slash)
		slash.hide()
		_flash_slashes.append(slash)
	_flash_label = Label.new()
	_flash_label.name = "BlackFlashWords"
	_flash_label.text = "BLACK FLASH!"
	_flash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_flash_label.anchor_left = 0.5
	_flash_label.anchor_right = 0.5
	_flash_label.anchor_top = 0.5
	_flash_label.anchor_bottom = 0.5
	_flash_label.offset_left = -230.0
	_flash_label.offset_right = 230.0
	_flash_label.offset_top = -48.0
	_flash_label.offset_bottom = 48.0
	_flash_label.pivot_offset = Vector2(230.0, 48.0)
	_flash_label.rotation = -0.055
	var words_style := LabelSettings.new()
	words_style.font_size = 46
	words_style.font_color = BLACK_FLASH_WORDS
	words_style.outline_size = 8
	words_style.outline_color = Color.BLACK
	words_style.shadow_size = 5
	words_style.shadow_color = Color.BLACK
	words_style.shadow_offset = Vector2(4.0, 5.0)
	_flash_label.label_settings = words_style
	_flash_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_label)
	_flash_label.hide()


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(INK.r, INK.g, INK.b, 0.82)
	style.border_color = Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.56)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _speed_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.94)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _clear_black_flash() -> void:
	if _flash_tween != null and _flash_tween.is_running():
		_flash_tween.kill()
	if _label_tween != null and _label_tween.is_running():
		_label_tween.kill()
	if _flash != null:
		_flash.hide()
	if _flash_label != null:
		_flash_label.hide()
	for slash in _flash_slashes:
		slash.hide()


func _on_flash_finished() -> void:
	_flash.hide()
	for slash in _flash_slashes:
		slash.hide()
	if _label_tween == null or not _label_tween.is_running():
		_flash_label.hide()
