extends Control
## Launcher bawaan APK tidak termasuk content pack. Tidak preload kode gameplay.

const Policy = preload("res://launcher/update_policy.gd")
const MANIFEST_URL := "https://github.com/KyokoApp/Godot/releases/latest/download/content.json"
const ACTIVE := "user://content.json"
const PENDING := "user://content_boot_pending"
const TEMP := "user://download.part"
const GAME := "res://src/game/main.tscn"

var _status: Label
var _bar: ProgressBar
var _buttons: HBoxContainer
var _request: HTTPRequest
var _active: Dictionary = {}
var _remote: Dictionary = {}
var _downloading := false
var _recovery := false


func _ready() -> void:
	_build_ui()
	_recovery = FileAccess.file_exists(PENDING)
	if _recovery:
		DirAccess.remove_absolute(PENDING)
		DirAccess.remove_absolute(ACTIVE)
	else:
		_active = _read_manifest(ACTIVE)
	_request = HTTPRequest.new()
	_request.timeout = 20.0
	_request.body_size_limit = 65536
	add_child(_request)
	_request.request_completed.connect(_manifest_done)
	if _recovery:
		_offer("Konten sebelumnya gagal dibuka. Masuk versi bawaan atau coba lagi.")
	else:
		_check_update()


func _build_ui() -> void:
	var background := Control.new()
	background.set_script(preload("res://launcher/backdrop.gd"))
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := Label.new()
	title.text = "A - S E K A I"
	title.add_theme_font_size_override("font_size", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title.position = Vector2(-320, -100)
	title.size = Vector2(640, 100)
	add_child(title)
	var subtitle := Label.new()
	subtitle.text = "S E B U A H   D U N I A   B A R U"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("bcb3df"))
	subtitle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	subtitle.position = Vector2(-320, 10)
	subtitle.size.x = 640
	add_child(subtitle)
	var bottom := VBoxContainer.new()
	add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 48
	bottom.offset_right = -48
	bottom.offset_top = -150
	bottom.offset_bottom = -32
	bottom.add_theme_constant_override("separation", 14)
	_status = Label.new()
	_status.text = "Menyiapkan perjalanan…"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_status)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size.y = 6
	_bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = Color("34445f")
	_bar.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("ceb8ff")
	_bar.add_theme_stylebox_override("fill", fill)
	bottom.add_child(_bar)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 24)
	bottom.add_child(_buttons)
	for caption in ["Coba lagi", "Main offline"]:
		var button := Button.new()
		button.text = caption
		button.custom_minimum_size = Vector2(200, 48)
		_buttons.add_child(button)
		if caption == "Coba lagi":
			button.pressed.connect(_check_update)
		else:
			button.pressed.connect(_launch)
	_buttons.hide()


func _read_manifest(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and Policy.valid_manifest(data):
		return data
	return {}


func _check_update() -> void:
	_buttons.hide()
	_bar.value = 3
	_status.text = "Memeriksa pembaruan…"
	_request.download_file = ""
	_request.body_size_limit = 65536
	_request.timeout = 20.0
	if _request.request(MANIFEST_URL) != OK:
		_offer("Tidak dapat terhubung. Versi tersimpan masih bisa dimainkan.")


func _manifest_done(
	result: int, code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_offer("Pembaruan belum tersedia / koneksi gagal. Coba lagi atau main offline.")
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary or not Policy.valid_manifest(data):
		_offer("Pembaruan tidak kompatibel. Gunakan versi tersimpan; cek release APK terbaru.")
		return
	_remote = data
	if (_active.get("sha256", "") == _remote["sha256"]
		and Policy.verified(_pack_path(_active), _active)):
		_launch()
		return
	_request.request_completed.disconnect(_manifest_done)
	_request.request_completed.connect(_download_done)
	_request.download_file = TEMP
	_request.body_size_limit = int(_remote["bytes"])
	_request.timeout = 180.0
	_downloading = true
	if _request.request(_remote["url"]) != OK:
		_download_done(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())


func _process(_delta: float) -> void:
	if _downloading:
		var received := _request.get_downloaded_bytes()
		var total: int = int(_remote["bytes"])
		_bar.value = 5.0 + 85.0 * clampf(float(received) / total, 0.0, 1.0)
		_status.text = "Mengunduh konten — %d%%  (%.1f / %.1f MB)" % [
			int(100.0 * received / total), received / 1048576.0, total / 1048576.0]


func _download_done(
	result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray
) -> void:
	_downloading = false
	_request.request_completed.disconnect(_download_done)
	_request.request_completed.connect(_manifest_done)
	_status.text = "Memverifikasi konten…"
	_bar.value = 92
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not Policy.verified(TEMP, _remote):
		DirAccess.remove_absolute(TEMP)
		_offer("Unduhan gagal / tidak utuh. Konten lama tetap aman. Coba lagi atau main offline.")
		return
	var destination := _pack_path(_remote)
	if DirAccess.rename_absolute(TEMP, destination) != OK:
		_offer("Tidak dapat menyimpan konten. Periksa ruang penyimpanan.")
		return
	var file := FileAccess.open(ACTIVE + ".tmp", FileAccess.WRITE)
	if file == null:
		_offer("Tidak dapat menyimpan versi konten.")
		return
	file.store_string(JSON.stringify(_remote))
	file.close()
	if DirAccess.rename_absolute(ACTIVE + ".tmp", ACTIVE) != OK:
		_offer("Tidak dapat mengaktifkan versi konten.")
		return
	_active = _remote
	_launch()


func _pack_path(manifest: Dictionary) -> String:
	return "user://content-%s.pck" % str(manifest.get("sha256", ""))


func _offer(message: String) -> void:
	_status.text = message
	_buttons.show()


func _launch() -> void:
	_buttons.hide()
	_status.text = "Membuka dunia…"
	_bar.value = 96
	await get_tree().process_frame
	if not _active.is_empty() and Policy.verified(_pack_path(_active), _active):
		var marker := FileAccess.open(PENDING, FileAccess.WRITE)
		if marker == null:
			_offer("Tidak dapat menyiapkan pemulihan. Periksa penyimpanan.")
			return
		marker.store_string("pending")
		marker.close()
		if not ProjectSettings.load_resource_pack(_pack_path(_active), true):
			DirAccess.remove_absolute(PENDING)
			DirAccess.remove_absolute(ACTIVE)
	_bar.value = 100
	# Muat setelah pack dipasang; launcher tidak menyimpan cache scene gameplay.
	var error := get_tree().change_scene_to_file(GAME)
	if error != OK:
		_status.text = "Konten gagal dibuka. Tutup dan buka aplikasi untuk pemulihan otomatis."
