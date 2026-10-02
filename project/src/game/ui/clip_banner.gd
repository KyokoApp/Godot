extends PanelContainer
## HUD kecil di kiri atas: nama animasi yang sedang tampil + progres + petunjuk.

const Mannequin = preload("res://src/game/mannequin.gd")
const TEXT := Color("f2ecff")
const DIM := Color("b7a9d6")

var character: Mannequin
var extra := ""
var _title: Label
var _detail: Label


func _ready() -> void:
	name = "ClipBanner"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.035, 0.07, 0.55)
	style.border_color = Color(1, 1, 1, 0.16)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	add_child(column)
	_title = _label(18, TEXT)
	_detail = _label(14, DIM)
	column.add_child(_title)
	column.add_child(_detail)


func _label(size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _process(_delta: float) -> void:
	if character == null:
		return
	_title.text = "%s  ·  %s" % [character.current_label(), character.clip]
	var state := "loop" if not character.is_busy() else "aksi"
	_detail.text = "%d%%  ·  %s%s" % [int(character.progress() * 100), state,
		("  ·  " + extra) if not extra.is_empty() else ""]
