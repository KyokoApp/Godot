extends SceneTree
## Boot launcher dari ISI APK yang sudah diekspor, bukan dari folder proyek.
##
## Bug nyata di HP: paket utama APK hanya memuat skrip milik scene-nya sendiri,
## sehingga preload chunk_policy/chunk_store/backdrop tidak ada di paket dan
## seluruh UI launcher gagal dimuat — layar jadi abu polos tanpa teks.
## Tes yang berjalan dari folder proyek tidak pernah bisa menangkap itu karena
## semua berkas sumber masih ada di sana.

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _run() -> void:
	var scene: PackedScene = load("res://launcher/main.tscn")
	if scene == null:
		_check(false, "Scene launcher tidak bisa dimuat dari isi APK")
		_finish()
		return
	var launcher: Control = scene.instantiate()
	root.add_child(launcher)
	current_scene = launcher
	await process_frame
	_check(launcher.get_script() != null, "Skrip launcher tidak ikut terpasang")
	var boot := launcher.find_child("BootLabel", true, false) as Label
	_check(boot != null, "Penanda boot launcher tidak digambar")
	var art := launcher.find_child("LoadingArt", true, false) as TextureRect
	_check(art != null, "Latar ilustrasi launcher tidak terbentuk")
	if art != null:
		print("[apk-launcher-test] tekstur loading: ",
			"ada" if art.texture != null else "tidak ada (latar polos)")
	var status := launcher.get("_status") as Label
	_check(status != null and not status.text.is_empty(), "Teks status launcher kosong")
	var policy: GDScript = load("res://launcher/chunk_policy.gd") as GDScript
	_check(policy != null, "chunk_policy.gd tidak ada di paket utama APK")
	var store: GDScript = load("res://launcher/chunk_store.gd") as GDScript
	_check(store != null, "chunk_store.gd tidak ada di paket utama APK")
	_finish()


func _finish() -> void:
	print("[apk-launcher-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
