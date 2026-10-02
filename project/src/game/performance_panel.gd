extends VBoxContainer
## Pembanding A/B perangkat nyata, bukan janji 60 FPS atau pengukuran GPU.

const SETTINGS := "user://graphics.cfg"

var rays: MeshInstance3D
var rays_enabled := true
var sun: DirectionalLight3D
var grass: Node3D
var light_mode := true
var grass_enabled := true
var shadows_enabled := false
var uncapped := false
var _rays_button: Button
var _quality: Button
var _grass_button: Button
var _shadows: Button
var _limit: Button
var _stats: Label
var _frames: Array[float] = []
var _elapsed := 0.0


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_load_settings()
	_quality = _button("", toggle_quality)
	_grass_button = _button("", toggle_grass)
	_shadows = _button("", toggle_shadows)
	_limit = _button("", toggle_limit)
	_rays_button = _button("", toggle_rays)
	_stats = Label.new()
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats.add_theme_font_size_override("font_size", 16)
	_stats.add_theme_color_override("font_shadow_color", Color.BLACK)
	add_child(_stats)
	apply_settings()


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(250, 46)
	button.add_theme_font_size_override("font_size", 18)
	button.focus_mode = Control.FOCUS_NONE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.19, 0.14, 0.29, 1)
	style.set_corner_radius_all(10)
	button.add_theme_stylebox_override("normal", style)
	var active := style.duplicate() as StyleBoxFlat
	active.bg_color = Color(0.32, 0.23, 0.47, 1)
	button.add_theme_stylebox_override("pressed", active)
	button.add_theme_stylebox_override("hover", active)
	button.add_theme_color_override("font_color", Color("e4ddf4"))
	button.pressed.connect(action)
	add_child(button)
	return button


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS) != OK:
		return
	light_mode = bool(config.get_value("graphics", "light", true))
	grass_enabled = bool(config.get_value("graphics", "grass", true))
	shadows_enabled = bool(config.get_value("graphics", "shadows", false))
	uncapped = bool(config.get_value("graphics", "uncapped", false))
	rays_enabled = bool(config.get_value("graphics", "moon_rays", true))


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("graphics", "light", light_mode)
	config.set_value("graphics", "grass", grass_enabled)
	config.set_value("graphics", "shadows", shadows_enabled)
	config.set_value("graphics", "uncapped", uncapped)
	config.set_value("graphics", "moon_rays", rays_enabled)
	config.save(SETTINGS)


func apply_settings() -> void:
	# Hanya resolusi 3D yang turun. Teks dan tombol tetap pada resolusi UI asli.
	get_viewport().scaling_3d_scale = 0.75 if light_mode else 1.0
	Engine.max_fps = 0 if uncapped else 60
	if sun != null:
		sun.shadow_enabled = shadows_enabled
	if grass != null:
		grass.visible = grass_enabled
		grass.set_process(grass_enabled)
	_quality.text = "Resolusi 3D: " + ("75% (Ringan)" if light_mode else "100% (Normal)")
	_grass_button.text = "Rumput: " + ("Nyala" if grass_enabled else "Mati (tes FPS)")
	_shadows.text = "Bayangan: " + ("Nyala" if shadows_enabled else "Mati")
	_limit.text = "Batas FPS: " + ("Bebas*" if uncapped else "60")
	if rays != null:
		rays.set("enabled", rays_enabled)
	_rays_button.text = "Sinar bulan: " + ("Nyala" if rays_enabled else "Mati (tes FPS)")
	_frames.clear()
	_elapsed = 0.0
	_stats.text = "Mengukur frame…\n* Tetap mengikuti VSync / layar HP"


func toggle_quality() -> void:
	light_mode = not light_mode
	apply_settings()
	_save_settings()


func toggle_grass() -> void:
	grass_enabled = not grass_enabled
	apply_settings()
	_save_settings()


func toggle_shadows() -> void:
	shadows_enabled = not shadows_enabled
	apply_settings()
	_save_settings()


func toggle_limit() -> void:
	uncapped = not uncapped
	apply_settings()
	_save_settings()


func _process(delta: float) -> void:
	_frames.append(delta * 1000.0)
	if _frames.size() > 120:
		_frames.pop_front()
	_elapsed += delta
	if _elapsed < 0.5:
		return
	_elapsed = 0.0
	var ordered: Array[float] = _frames.duplicate()
	ordered.sort()
	var total := 0.0
	for duration in ordered:
		total += duration
	var p95 := ordered[clampi(ceili(ordered.size() * 0.95) - 1, 0, ordered.size() - 1)]
	var calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_stats.text = "Frame: %.1f ms | P95: %.1f\nDraw calls: %d | 60 FPS = 16,7 ms\n" % [
		total / ordered.size(), p95, calls]
	_stats.text += "* Bebas tetap mengikuti VSync / layar"


func _exit_tree() -> void:
	Engine.max_fps = 0
	get_viewport().scaling_3d_scale = 1.0


func toggle_rays() -> void:
	rays_enabled = not rays_enabled
	apply_settings()
	_save_settings()
