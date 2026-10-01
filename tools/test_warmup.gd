extends SceneTree
## Actual Vulkan warmup/skip lifecycle; no claims about phone FPS from this test.

const Warmup = preload("res://src/game/loading/shader_warmup.gd")
const Samples = preload("res://src/game/loading/warmup_samples.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _run() -> void:
	var marker := FileAccess.open("user://content_boot_pending", FileAccess.WRITE)
	marker.store_string("test warmup")
	marker.close()
	var scene: PackedScene = load("res://src/game/main.tscn")
	var game := scene.instantiate() as Node3D
	game.set("warmup_requested", true)
	root.add_child(game)
	var warmup: Warmup
	for frame in range(20):
		await process_frame
		warmup = game.get_node_or_null("ShaderWarmup") as Warmup
		if warmup != null:
			break
	_check(warmup != null, "Warmup produksi tidak dimulai")
	if warmup == null:
		quit(1)
		return
	_check(FileAccess.file_exists("user://content_boot_pending"),
		"Boot dikonfirmasi sebelum warmup selesai")
	_check(game.process_mode == Node.PROCESS_MODE_DISABLED, "Gameplay berjalan di belakang loading")
	var before: Vector3 = game.get("_player").position
	var observed := false
	while not game.get("warmup_complete"):
		await process_frame
		if is_instance_valid(warmup) and warmup.completed_stages > 0:
			observed = true
			_check(game.get("_player").position.is_equal_approx(before),
				"Pemain bergerak selama loading")
	_check(observed, "Tidak ada stage yang benar-benar dirender")
	var report: Dictionary = game.get("warmup_report")
	_check(report.get("stages", 0) > 0 and report.get("total", 0) == Samples.STAGES,
		"Laporan tahap tidak valid")
	_check(not FileAccess.file_exists("user://content_boot_pending"), "Boot marker belum dibersihkan")
	_check(game.process_mode == Node.PROCESS_MODE_INHERIT, "Gameplay tidak dipulihkan")
	await process_frame
	_check(game.find_child("WarmupViewport", true, false) == null, "Viewport warmup bocor")
	_check(game.get("_attack").is_visible_in_tree(), "HUD tidak muncul setelah warmup")
	for voice in game.get("_audio").get("voices"):
		_check(not voice.stream_paused, "Audio tetap pause setelah loading")
	# Skip must use the same cleanup path, not strand gameplay in DISABLED mode.
	var skipped := Warmup.new()
	game.add_child(skipped)
	skipped.request_skip()
	var skip_report: Dictionary = await skipped.run(game)
	_check(skip_report["skipped"] and skip_report["stages"] == 0, "Skip diabaikan")
	_check(game.process_mode == Node.PROCESS_MODE_INHERIT, "Skip tidak memulihkan input")
	skipped.queue_free()
	game.queue_free()
	await process_frame
	await RenderingServer.frame_post_draw
	print("[warmup-test] report=", JSON.stringify(report))
	print("[warmup-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
