extends SceneTree
## UJI COMPILE SEMUA SKRIP — wajib jalan di SETIAP build.
##
## Pelajaran mahal dari project lama (2026-09-29): aplikasi menampilkan
## layar biru tanpa loading screen. Penyebabnya satu baris:
##
##     var lbl := ["VERSI", "MODE", "GRAFIK", "STATUS"][k2]
##
## Indeks ke Array literal menghasilkan Variant, dan `:=` dari Variant
## adalah COMPILE ERROR di Godot 4.5 — bukan error runtime. Skrip itu
## di-preload oleh skrip utama, jadi satu baris mematikan seluruh
## aplikasi; yang tersisa hanya warna latar boot.
##
## Kenapa tidak tertangkap waktu itu:
##   - gdparse hanya cek sintaks, bukan inferensi tipe engine
##   - probe lama hanya memuat skrip di dalam folder pack, skrip
##     non-pack seperti launcher TIDAK PERNAH dikompilasi di CI sama sekali
##
## Skrip ini menutup celah itu: load() SETIAP .gd di res:// memakai engine
## sungguhan. Kalau build hijau, berarti APK yang terbit PASTI bisa
## lewat kompilasi di perangkat.
##
## Dijalankan CI:
##   godot --headless --path project --script ../tools/compile_check.gd

func _init() -> void:
	var scripts: Array[String] = []
	_walk("res://", scripts)
	scripts.sort()

	var failed: Array[String] = []
	for path in scripts:
		var script: Resource = load(path)
		if script == null:
			failed.append(path)
		elif not (script is GDScript):
			failed.append(path + "  (bukan GDScript)")

		elif not (script as GDScript).can_instantiate():
			failed.append(path + "  (compile gagal)")

	print("[compile-check] %d skrip diperiksa, %d gagal" % [scripts.size(), failed.size()])
	for f in failed:
		print("[compile-check] GAGAL: ", f)
	if not failed.is_empty():
		print("[compile-check] HASIL: GAGAL")
		quit(1)
		return
	print("[compile-check] HASIL: OK")
	quit(0)


func _walk(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full_path := dir_path.path_join(entry)
			if dir.current_is_dir():
				_walk(full_path, out)
			elif entry.ends_with(".gd"):
				out.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()
