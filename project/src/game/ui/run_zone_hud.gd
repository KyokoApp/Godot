extends Control
## Status Run Zone: waktu lari dan laju saat ini, tanpa tombol aksi tambahan.

const INK := Color("171722")
const PAPER := Color("f2ecff")
const PURPLE := Color("c69aff")

var _panel: PanelContainer
var _title: Label
var _detail: Label


func _ready() -> void:
	name = "RunZoneHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.name = "RunStatusPanel"
	_panel.position = Vector2(18.0, 18.0)
	_panel.custom_minimum_size = Vector2(276.0, 0.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	_panel.add_child(column)
	_title = _label("RUN ZONE", 14, PURPLE)
	_detail = _label("PENYIHIR MENYIAPKAN MANTRA", 13, PAPER)
	column.add_child(_title)
	column.add_child(_detail)
	hide()


func show_intro() -> void:
	_title.text = "RUN ZONE"
	_detail.text = "PENYIHIR MENYIAPKAN MANTRA"
	show()


func show_running(elapsed_seconds: float, speed: float) -> void:
	var total_seconds := maxi(0, floori(elapsed_seconds))
	var minutes := int(total_seconds / 60)
	var seconds := total_seconds % 60
	_title.text = "RUN ZONE"
	_detail.text = "WAKTU %02d:%02d   ·   %.1f m/s" % [minutes, seconds, speed]
	show()


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(INK.r, INK.g, INK.b, 0.78)
	style.border_color = Color(PURPLE.r, PURPLE.g, PURPLE.b, 0.46)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
