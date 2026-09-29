extends VBoxContainer
## Offline notices; loaded from exported text, not a network page or external dependency.

var _files := PackedStringArray()
var _selector: OptionButton
var _body: RichTextLabel


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_selector = OptionButton.new()
	_selector.custom_minimum_size.y = 44
	_selector.add_theme_font_size_override("font_size", 17)
	add_child(_selector)
	_body = RichTextLabel.new()
	_body.custom_minimum_size = Vector2(0, 320)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.selection_enabled = true
	_body.add_theme_font_size_override("normal_font_size", 17)
	add_child(_body)
	_files.append("CREDITS.txt")
	var remaining := DirAccess.get_files_at("res://licenses")
	remaining.sort()
	for file in remaining:
		if file.ends_with(".txt") and file != "CREDITS.txt":
			_files.append(file)
	for file in _files:
		_selector.add_item(file.trim_suffix(".txt"))
	_selector.item_selected.connect(_select)
	_select(0)


func _select(index: int) -> void:
	# Plain text: notices are not executable BBCode; source URLs can be selected/copied.
	_body.text = FileAccess.get_file_as_string("res://licenses/" + _files[index])
	_body.scroll_to_line(0)
