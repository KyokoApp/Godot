extends RefCounted
## Jejak boot: satu baris per tahap, ditulis ke penyimpanan aplikasi.
##
## Gunanya untuk kasus "aplikasi berhenti sendiri": kalau aplikasi mati sebelum
## tahap terakhir ("game ready") tercatat, peluncuran berikutnya bisa menunjukkan
## tahap terakhir yang sempat dicapai — di HP yang tidak mengeluarkan log apa pun,
## ini satu-satunya jejak yang bisa dibaca pengguna.

const PATH := "user://boot_trace.txt"
const READY := "game ready"


static func write(stage: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line("%s %s" % [Time.get_datetime_string_from_system(false, true), stage])
	file.close()


static func start() -> String:
	# Kembalikan tahap terakhir dari sesi sebelumnya, lalu mulai jejak baru.
	var previous := last_stage()
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file != null:
		file.store_line("%s launcher start" % Time.get_datetime_string_from_system(false, true))
		file.close()
	return previous


static func last_stage() -> String:
	if not FileAccess.file_exists(PATH):
		return ""
	var text := FileAccess.get_file_as_string(PATH)
	var lines := text.strip_edges().split("\n")
	if lines.is_empty():
		return ""
	var last := lines[lines.size() - 1].strip_edges()
	if last.is_empty():
		return ""
	# Baris berbentuk "<tanggal> <jam> <tahap>"; ambil tahapnya saja.
	var parts := last.split(" ", false)
	if parts.size() <= 2:
		return last
	return " ".join(parts.slice(2))
