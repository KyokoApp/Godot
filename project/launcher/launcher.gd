extends Control
## Launcher v2. Network blocks are never mounted; only a verified complete pack is.
const Policy = preload("res://launcher/chunk_policy.gd")
const Store = preload("res://launcher/chunk_store.gd")
const MANIFEST_URL := "https://github.com/KyokoApp/Godot/releases/latest/download/content-v2.json"
const PENDING := "user://content_boot_pending"
const TEMP := Store.ROOT + "download.part"
const GAME := "res://src/game/main.tscn"

var _status: Label
var _bar: ProgressBar
var _buttons: HBoxContainer
var _request: HTTPRequest
var _active: Dictionary = {}
var _seed: Dictionary = {}
var _remote: Dictionary = {}
var _store: Store
var _downloading := false
var _busy := false
var _recovery := false
var _received := 0
var _next := 0


func _ready() -> void:
	_build_ui()
	DirAccess.make_dir_recursive_absolute(Store.ROOT)
	_recovery = FileAccess.file_exists(PENDING)
	if _recovery:
		Store.rollback()
		DirAccess.remove_absolute(PENDING)
	_active = Store.read_index(Store.ACTIVE)
	_seed = Store.read_index(Store.SEED_INDEX)
	if not _recovery:
		Store.cleanup()
	_request = HTTPRequest.new()
	_request.accept_gzip = false # Hashes and byte counts cover exact published bytes.
	add_child(_request)
	_request.request_completed.connect(_manifest_done)
	if _recovery:
		_offer("Boot sebelumnya terputus. Versi sebelumnya tersedia; coba lagi atau main offline.")
	else:
		_check_update()


func _build_ui() -> void:
	# Paling awal: penanda boot polos tanpa tekstur/skrip lain, supaya layar tidak
	# pernah benar-benar kosong saat ada bagian paket yang gagal dimuat.
	var boot := ColorRect.new()
	boot.name = "BootMark"
	boot.color = Color(0.05, 0.07, 0.14)
	boot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(boot)
	boot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var boot_label := Label.new()
	boot_label.name = "BootLabel"
	boot_label.text = "A - S E K A I  memuat…"
	boot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boot_label.add_theme_font_size_override("font_size", 28)
	boot_label.add_theme_color_override("font_color", Color("dfd1fa"))
	boot_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	boot_label.position = Vector2(-320, -20)
	boot_label.size = Vector2(640, 40)
	add_child(boot_label)
	var background := Control.new()
	var backdrop_script: Script = load("res://launcher/backdrop.gd") as Script
	if backdrop_script != null:
		background.set_script(backdrop_script)
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_child(background, 0)
	move_child(boot, 0)
	var title := Label.new()
	title.text = "A - S E K A I"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_shadow_color", Color(0.03, 0.05, 0.10, 0.8))
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title.position = Vector2(-320, -100)
	title.size = Vector2(640, 100)
	add_child(title)
	var subtitle := Label.new()
	subtitle.text = "S E B U A H   D U N I A   B A R U"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("ece6ff"))
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
	_status.add_theme_color_override("font_shadow_color", Color.BLACK)
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


func _check_update() -> void:
	if _busy:
		return
	_busy = true
	_buttons.hide()
	_bar.value = 3
	_status.text = "Memeriksa pembaruan…"
	_request.download_file = ""
	_request.body_size_limit = Policy.MAX_MANIFEST
	_request.timeout = 20.0
	if _request.request(MANIFEST_URL) != OK:
		_offer("Tidak dapat terhubung. Versi tersimpan masih bisa dimainkan.")


func _manifest_done(
	result: int, code: int, _headers: PackedStringArray, body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_offer("Koneksi gagal. Coba lagi atau main offline.")
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary or not Policy.valid(data):
		_offer("Manifest tidak kompatibel. Main offline atau periksa APK terbaru.")
		return
	_remote = data
	if _matching_local():
		_busy = false
		_launch()
		return
	_status.text = "Memeriksa data tersimpan—hanya bagian berubah yang diunduh…"
	_store = Store.new()
	_store.add_source(Store.pack_path(_active), _active)
	var previous := Store.read_index(Store.PREVIOUS)
	_store.add_source(Store.pack_path(previous), previous)
	_store.add_source(Store.SEED, _seed)
	await _store.plan(_remote, get_tree())
	_received = 0
	_next = 0
	_request.request_completed.disconnect(_manifest_done)
	_request.request_completed.connect(_download_done)
	await _download_next()


func _matching_local() -> bool:
	if _active.get("sha256", "") == _remote.sha256 \
			and Policy.verified(Store.pack_path(_active), _active):
		return true
	# A newly installed APK already contains this exact build. Do not redownload it.
	if _seed.get("sha256", "") == _remote.sha256 and Policy.verified(Store.SEED, _seed):
		_active = {}
		DirAccess.remove_absolute(Store.ACTIVE)
		DirAccess.remove_absolute(Store.PREVIOUS)
		return true
	return false


func _download_next() -> void:
	if _next >= _store.missing.size():
		_reset_request()
		_status.text = "Menyusun dan memverifikasi pembaruan…"
		_bar.value = 92
		if not await _store.assemble(_remote, get_tree()) or not Store.activate(_remote):
			_offer("Penyimpanan/verifikasi gagal. Data lama aman. Coba lagi atau main offline.")
			return
		_active = _remote
		_busy = false
		_launch()
		return
	var chunk: Dictionary = _store.missing[_next]
	_request.download_file = TEMP
	_request.body_size_limit = int(chunk.bytes)
	_request.timeout = 90.0
	_downloading = true
	if _request.request(Policy.chunk_url(_remote, chunk)) != OK:
		_download_done(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())


func _download_done(
	result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray
) -> void:
	_downloading = false
	var chunk: Dictionary = _store.missing[_next]
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not _store.accept_chunk(TEMP, chunk):
		DirAccess.remove_absolute(TEMP)
		_reset_request()
		_offer("Unduhan terputus/rusak. Blok yang selesai disimpan; data lama tetap aman.")
		return
	_received += int(chunk.bytes)
	_next += 1
	await _download_next()


func _reset_request() -> void:
	_downloading = false
	_request.request_completed.disconnect(_download_done)
	_request.request_completed.connect(_manifest_done)


func _process(_delta: float) -> void:
	if _downloading:
		var received := _received + _request.get_downloaded_bytes()
		var total := maxi(1, _store.download_bytes)
		_bar.value = 5 + 85 * clampf(float(received) / total, 0, 1)
		_status.text = "Bagian berubah — %.1f / %.1f MB" % [
			received / 1048576.0, total / 1048576.0]


func _offer(message: String) -> void:
	_busy = false
	_status.text = message
	_buttons.show()


func _launch() -> void:
	if _busy:
		return
	_busy = true
	_buttons.hide()
	_status.text = "Membuka dunia…"
	_bar.value = 96
	await get_tree().process_frame
	var path := Store.pack_path(_active)
	var downloaded := Policy.verified(path, _active)
	if not downloaded:
		path = Store.SEED
		if not _seed.is_empty() and not Policy.verified(path, _seed):
			_offer("Data bawaan rusak. Pasang ulang APK tanpa menghapus data aplikasi.")
			return
	if FileAccess.file_exists(path):
		if downloaded:
			var marker := FileAccess.open(PENDING, FileAccess.WRITE)
			if marker == null:
				_offer("Tidak dapat menyiapkan pemulihan. Periksa ruang penyimpanan.")
				return
			marker.store_string(str(_active.sha256))
			marker.close()
		if not ProjectSettings.load_resource_pack(path, true):
			_status.text = "Paket gagal dibuka. Tutup dan buka aplikasi untuk pemulihan."
			return # Never mix a partially mounted pack with another build in this process.
	_bar.value = 100
	# Editor/tests may use unpacked gameplay; production APK has only the bundled seed.
	if get_tree().change_scene_to_file(GAME) != OK:
		_status.text = "Konten gagal dibuka. Tutup dan buka aplikasi untuk pemulihan."
