extends CanvasLayer
## Best-effort warmup, NOT a guarantee that every future GPU pipeline is cached.

const Samples = preload("res://src/game/loading/warmup_samples.gd")
const Night = preload("res://src/game/environment/night_environment.gd")
const SOFT_LIMIT_MS := 20000

var cancel_requested := false
var report: Dictionary = {}
var completed_stages := 0
var _bar: ProgressBar
var _status: Label
var _viewport: SubViewport
var _world: Node3D


func _ready() -> void:
	name = "ShaderWarmup"
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func request_skip() -> void:
	cancel_requested = true


func _build_ui() -> void:
	var cover := ColorRect.new()
	cover.color = Color("0c1024")
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	# Reuse the installed launcher's approved art; isolated PCK tests may lack it.
	var art_path := "res://launcher/art/loading.jpg"
	if ResourceLoader.exists(art_path):
		var picture := TextureRect.new()
		picture.texture = load(art_path) as Texture2D
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.add_child(picture)
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var shade := ColorRect.new()
		shade.color = Color(0.02, 0.03, 0.08, 0.45)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cover.add_child(shade)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := Label.new()
	title.text = "A — SEKAI"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("dfd1fa"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cover.add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title.position = -Vector2(180, 40)
	title.size = Vector2(360, 70)
	var bottom := VBoxContainer.new()
	cover.add_child(bottom)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 40
	bottom.offset_right = -40
	bottom.offset_top = -140
	bottom.offset_bottom = -24
	bottom.add_theme_constant_override("separation", 12)
	_status = Label.new()
	_status.text = "Menyiapkan shader dan material…"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_status)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size.y = 4
	_bar.show_percentage = false
	_bar.max_value = Samples.STAGES
	var track := StyleBoxFlat.new()
	track.bg_color = Color("24243b")
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("bfa8f4")
	_bar.add_theme_stylebox_override("background", track)
	_bar.add_theme_stylebox_override("fill", fill)
	bottom.add_child(_bar)
	var skip := Button.new()
	skip.text = "Lanjut tanpa menunggu"
	skip.custom_minimum_size.y = 44
	skip.pressed.connect(request_skip)
	bottom.add_child(skip)


func run(game: Node3D) -> Dictionary:
	var start := Time.get_ticks_msec()
	var before := _draw_compilations()
	var previous_mode := game.process_mode
	var layers: Array[CanvasLayer] = []
	for child in game.get_children():
		if child is CanvasLayer and child != self and child.visible:
			layers.append(child)
			child.hide()
	game.get("_joystick").reset()
	game.get("_orbit").reset_touches()
	game.get("_attack").reset_touch()
	game.get("_settings").reset_touch()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var paused_voices: Array[AudioStreamPlayer3D] = []
	var audio: Node3D = game.get("_audio")
	for voice: AudioStreamPlayer3D in audio.get("voices"):
		if not voice.stream_paused:
			voice.stream_paused = true
			paused_voices.append(voice)
	_build_viewport(game)
	await RenderingServer.frame_post_draw
	for stage in range(Samples.STAGES):
		if cancel_requested or (stage > 0 and Time.get_ticks_msec() - start > SOFT_LIMIT_MS):
			break
		_status.text = "Menyiapkan tampilan — tahap %d / %d" % [stage + 1, Samples.STAGES]
		var sample := Node3D.new()
		_world.add_child(sample)
		Samples.populate(stage, sample, game)
		# A real rendered frame is essential; merely loading a .gdshader is not enough.
		for frame in range(4):
			await RenderingServer.frame_post_draw
		completed_stages += 1
		_bar.value = completed_stages
		sample.queue_free()
		await get_tree().process_frame
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.queue_free()
	await get_tree().process_frame
	for voice in paused_voices:
		if is_instance_valid(voice):
			voice.stream_paused = false
	for hud in layers:
		if is_instance_valid(hud):
			hud.show()
	game.process_mode = previous_mode
	report = {"stages": completed_stages, "total": Samples.STAGES,
		"elapsed_ms": Time.get_ticks_msec() - start, "skipped": cancel_requested,
		"partial": completed_stages < Samples.STAGES,
		"draw_compilations_delta": maxi(0, _draw_compilations() - before)}
	print("[shader-warmup] ", JSON.stringify(report))
	# Diagnostic only, not a persistent 'all shaders compiled' flag.
	var file := FileAccess.open("user://shader_warmup_last.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report))
	return report


func _build_viewport(game: Node3D) -> void:
	_viewport = SubViewport.new()
	_viewport.name = "WarmupViewport"
	_viewport.size = Vector2i(320, 180)
	_viewport.own_world_3d = true
	_viewport.msaa_3d = game.get_viewport().msaa_3d
	_viewport.scaling_3d_scale = game.get_viewport().scaling_3d_scale
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	var environment := WorldEnvironment.new()
	environment.environment = Night.make_environment()
	_world.add_child(environment)
	var light := Night.make_moonlight()
	var source: DirectionalLight3D = game.get("_sun")
	light.shadow_enabled = source.shadow_enabled
	_world.add_child(light)
	light.global_transform = source.global_transform
	var camera := Camera3D.new()
	_world.add_child(camera)
	camera.position = Vector3(0, 2.8, 6)
	camera.look_at(Vector3(0, 1.4, 0))
	camera.current = true


func _draw_compilations() -> int:
	return RenderingServer.get_rendering_info(
		RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW)
