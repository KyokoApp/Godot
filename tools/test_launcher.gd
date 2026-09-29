extends SceneTree
## Jalankan UI dan jalur pemulihan/offline tanpa ketergantungan jaringan.

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var marker := FileAccess.open("user://content_boot_pending", FileAccess.WRITE)
	marker.store_string("simulasi boot terputus")
	marker.close()
	var scene: PackedScene = load("res://launcher/main.tscn")
	var launcher: Control = scene.instantiate()
	root.add_child(launcher)
	current_scene = launcher
	await process_frame
	var art := launcher.find_child("LoadingArt", true, false) as TextureRect
	_check(art != null and art.texture != null, "Ilustrasi loading tidak terbaca")
	_check(not FileAccess.file_exists("user://content_boot_pending"), "Marker tidak pulih")
	var buttons: HBoxContainer = launcher.get("_buttons")
	_check(buttons.visible, "Pilihan pemulihan tidak tampil")
	launcher.call("_manifest_done", HTTPRequest.RESULT_CANT_CONNECT, 0,
		PackedStringArray(), PackedByteArray())
	_check(buttons.visible, "Mode offline tidak ditawarkan setelah koneksi gagal")
	launcher.call("_manifest_done", HTTPRequest.RESULT_SUCCESS, 200,
		PackedStringArray(), "{bad json".to_utf8_buffer())
	_check(buttons.visible, "Manifest rusak tidak ditangani")
	launcher.call("_launch")
	for frame in range(8):
		await process_frame
	_check(current_scene is Node3D, "Gameplay bawaan tidak terbuka secara offline")
	print("[launcher-test] gagal: ", _failures)
	quit(0 if _failures == 0 else 1)
