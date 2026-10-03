extends Node3D
## Pulau 100 m × 100 m dengan bukit bergulir, garis pantai berlekuk, pemain
## beranimasi, dan seorang NPC. Karakter memakai katalog 85 klip UAL1 + UAL2.

const Field = preload("res://src/game/world/field.gd")
const Scenery = preload("res://src/game/world/scenery.gd")
const Forest = preload("res://src/game/world/forest.gd")
const NPC = preload("res://src/game/world/npc.gd")
const NPCInteraction = preload("res://src/game/ui/npc_interaction.gd")
const ModeSelector = preload("res://src/game/ui/game_mode_selector.gd")
const SurvivalWorld = preload("res://src/game/world/survival_world.gd")
const Grass = preload("res://src/game/grass_field.gd")
const Player = preload("res://src/game/player.gd")
const Character = preload("res://src/game/mannequin.gd")
const Orbit = preload("res://src/game/orbit_camera.gd")
const Joystick = preload("res://src/game/virtual_joystick.gd")
const Dusk = preload("res://src/game/environment/dusk_environment.gd")
const WorldAudio = preload("res://src/game/audio/world_audio.gd")
const Footsteps = preload("res://src/game/audio/footsteps.gd")
const FootFire = preload("res://src/game/foot_fire/foot_fire_trail.gd")
const SpeedAura = preload("res://src/game/speed/speed_aura.gd")
const FirePet = preload("res://src/game/fire_pet.gd")
const RuneButton = preload("res://src/game/ui/rune_button.gd")
const SpeedButton = preload("res://src/game/ui/speed_button.gd")
const AnimationPanel = preload("res://src/game/ui/animation_panel.gd")
const ClipBanner = preload("res://src/game/ui/clip_banner.gd")
const Catalog = preload("res://src/game/animation/catalog.gd")
const PerformancePanel = preload("res://src/game/performance_panel.gd")
const ShaderWarmup = preload("res://src/game/loading/shader_warmup.gd")
## Jejak boot ditulis langsung ke berkas yang sama dengan launcher (lihat
## project/launcher/boot_trace.gd). Tidak boleh preload skrip launcher di sini:
## main.gd ikut ke PCK sedangkan launcher/* justru dikecualikan dari PCK.
const BOOT_TRACE := "user://boot_trace.txt"
const BOOT_READY := "game ready"
const FIRE_ICON = preload("res://src/game/ui/flame.svg")
const SETTINGS_ICON = preload("res://src/game/ui/settings.svg")
const SPEED_ICON = preload("res://src/game/ui/speed.svg")
const SWORD_ICON = preload("res://src/game/ui/sword.svg")
const JUMP_ICON = preload("res://src/game/ui/jump.svg")
const CROUCH_ICON = preload("res://src/game/ui/crouch.svg")
const DASH_ICON = preload("res://src/game/ui/dash.svg")
## Titik muncul pemain di padang 100 m; dijaga kosong dari dedaunan.
const SPAWN := Vector2(0.0, 7.0)
const NPC_HOME := Vector2(0.0, 0.0)
## HUD gaya game aksi: satu tombol serang besar, tombol aksi bulat di sekitarnya.
const ATTACK_DIAMETER := 136.0
const FIRE_DIAMETER := 100.0
const ACTION_DIAMETER := 94.0
const DASH_DIAMETER := 94.0
const SPEED_DIAMETER := 88.0
const RUNE_DIAMETER := 68.0

var warmup_requested := false
var warmup_complete := false
var warmup_report: Dictionary = {}
var _previous_occlusion := false
var _field: Field
var _scenery: Scenery
var _forest: Forest
var _grass: Grass
var _player: Player
var _npc: NPC
var _npc_interaction: NPCInteraction
var _mode_selector: ModeSelector
var _survival_world: SurvivalWorld
var _active_mode := "hub"
var _visual: Character
var _bloom_level := 0.0
var _orbit: Orbit
var _sun: DirectionalLight3D
var _audio: WorldAudio
var _footsteps: Footsteps
var _foot_fire: FootFire
var _speed_aura: SpeedAura
var _pet: FirePet
var _joystick: Joystick
var _attack: RuneButton
var _fire_button: RuneButton
var _settings: RuneButton
var _layout_button: RuneButton
var _speed_button: SpeedButton
var _jump: Button
var _crouch: Button
var _dash: Button
var _catalog_button: Button
var _banner: ClipBanner
var _panel: AnimationPanel
var _performance: PerformancePanel
var _graphics_drawer: PanelContainer
var _survival_panel: PanelContainer
var _survival_status: Label
var _health_bar: ProgressBar
var _health_text: Label
var _hud_layer: CanvasLayer
var _layout_editor: PanelContainer
var _layout_target: OptionButton
var _layout_size: HSlider
var _layout_x: HSlider
var _layout_y: HSlider
var _layout_readout: Label
var _hud_controls: Dictionary = {}
var _hud_layout: Dictionary = {}
var _hud_layout_defaults: Dictionary = {}
var _layout_suppress := false


func _ready() -> void:
	_previous_occlusion = get_viewport().use_occlusion_culling
	get_viewport().use_occlusion_culling = true
	_build_environment()
	_build_world()
	_build_player()
	_build_npc()
	_build_camera()
	_build_grass()
	_build_effects()
	_build_hud()
	print("[main] pulau %.0f m + pemain + NPC (%d klip) siap" % [
		Field.SIZE, Catalog.clip_count()])
	_confirm_boot.call_deferred()


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "DuskEnvironment"
	world_environment.environment = Dusk.make_environment()
	add_child(world_environment)
	_sun = Dusk.make_sunlight()
	add_child(_sun)
	_sun.look_at_from_position(Vector3.ZERO, -Dusk.SUN_DIRECTION)


func _build_world() -> void:
	_field = Field.new()
	add_child(_field)
	# Pemandangan di luar pulau: bukit jauh, tebing batu, laut, reruntuhan batu,
	# titik cahaya — disusun seperti ilustrasi layar muat. Tanpa collision, jadi
	# gameplay di pulau tidak berubah.
	_scenery = Scenery.new()
	add_child(_scenery)
	# Dedaunan Quaternius (pohon, semak, batu, pakis, bunga) di dalam pulau.
	# MultiMesh: satu panggilan gambar per model, tidak ada collision.
	_forest = Forest.new()
	add_child(_forest)


func _build_player() -> void:
	_player = Player.new()
	_player.field = _field
	# Chunk tanah mengikuti pemain; tanpa ini pulau tidak pernah memuat chunk
	# baru dan tanahnya berlubang di belakang pemain.
	_field.player = _player
	add_child(_player)
	_visual = Character.new()
	_visual.sword_layer_enabled = true
	_visual.name = "Visual"
	_visual.position.y = -Player.HEIGHT * 0.5
	_player.add_child(_visual)
	_player.visual = _visual
	_player.spawn(SPAWN)
	_player.health_changed.connect(_on_health_changed)


func _build_npc() -> void:
	_npc = NPC.new()
	_npc.name = "Mira"
	_npc.field = _field
	_npc.player = _player
	_npc.home = NPC_HOME
	add_child(_npc)


func _build_camera() -> void:
	_orbit = Orbit.new()
	add_child(_orbit)
	_orbit.position = _player.global_position + Vector3(0, 0.9, 0)
	_player.orbit = _orbit


func _build_grass() -> void:
	_grass = Grass.new()
	_grass.ground = _field
	_grass.player = _player
	add_child(_grass)


func _build_effects() -> void:
	_audio = WorldAudio.new()
	_audio.listener = _orbit.camera
	add_child(_audio)
	_footsteps = Footsteps.new()
	_footsteps.audio = _audio
	_footsteps.body = _player
	_footsteps.field = _field
	_footsteps.visual = _visual
	add_child(_footsteps)
	_foot_fire = FootFire.new()
	_foot_fire.character = _visual
	_foot_fire.body = _player
	_foot_fire.field = _field
	add_child(_foot_fire)
	_speed_aura = SpeedAura.new()
	_speed_aura.character = _visual
	_speed_aura.environment = get_node("DuskEnvironment").environment
	add_child(_speed_aura)
	_pet = FirePet.new()
	_pet.player = _player
	_pet.facing = _visual
	_pet.camera = _orbit.camera
	_pet.cast_started.connect(_visual.start_cast)
	add_child(_pet)
	_audio.follow_fire(_pet)


func _build_survival_hud(layer: CanvasLayer) -> void:
	_survival_panel = PanelContainer.new()
	_survival_panel.name = "SurvivalStatus"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.035, 0.03, 0.86)
	style.border_color = Color("8db66c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_survival_panel.add_theme_stylebox_override("panel", style)
	layer.add_child(_survival_panel)
	_survival_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_survival_panel.offset_left = 20
	_survival_panel.offset_top = 76
	_survival_panel.offset_right = 258
	_survival_panel.offset_bottom = 146
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	_survival_panel.add_child(content)
	_survival_status = Label.new()
	_survival_status.text = "SURVIVAL   00:00   ·   ZOMBI 0"
	_survival_status.add_theme_font_size_override("font_size", 13)
	_survival_status.add_theme_color_override("font_color", Color("f2f0e8"))
	content.add_child(_survival_status)
	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 8)
	content.add_child(health_row)
	_health_text = Label.new()
	_health_text.text = "HP"
	_health_text.add_theme_font_size_override("font_size", 11)
	_health_text.add_theme_color_override("font_color", Color("bdd1b0"))
	health_row.add_child(_health_text)
	_health_bar = ProgressBar.new()
	_health_bar.name = "HealthBar"
	_health_bar.min_value = 0
	_health_bar.max_value = Player.MAX_HEALTH
	_health_bar.value = Player.MAX_HEALTH
	_health_bar.show_percentage = false
	_health_bar.custom_minimum_size = Vector2(178, 14)
	_health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_health_bar.add_theme_stylebox_override("background", _progress_style(Color(0.11, 0.14, 0.11, 1)))
	_health_bar.add_theme_stylebox_override("fill", _progress_style(Color("8cc46a")))
	health_row.add_child(_health_bar)
	_survival_panel.hide()


func _progress_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	return style


# ------------------------------------------------------------------ HUD ----

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "GameplayHUD"
	_hud_layer = layer
	add_child(layer)
	_joystick = Joystick.new()
	layer.add_child(_joystick)
	_joystick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player.joystick = _joystick
	_banner = ClipBanner.new()
	_banner.character = _visual
	layer.add_child(_banner)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_banner.offset_left = 20
	_banner.offset_top = 20
	_build_survival_hud(layer)
	# --- sudut kanan atas: dua tombol kecil bulat ---------------------------
	_settings = _rune("GRAFIK", RUNE_DIAMETER, SETTINGS_ICON)
	_settings.name = "GraphicsRune"
	_settings.compact = true
	_settings.tooltip_text = "Pengaturan grafik"
	layer.add_child(_settings)
	_place(_settings, Control.PRESET_TOP_RIGHT, -88, 100)
	_settings.pressed.connect(_toggle_graphics)
	_layout_button = _rune("HUD", RUNE_DIAMETER, SETTINGS_ICON)
	_layout_button.name = "LayoutRune"
	_layout_button.compact = true
	_layout_button.tooltip_text = "Atur ukuran dan posisi tombol"
	layer.add_child(_layout_button)
	_place(_layout_button, Control.PRESET_TOP_RIGHT, -166, 100)
	_layout_button.pressed.connect(_toggle_layout_editor)
	_catalog_button = _rune("ANIM", RUNE_DIAMETER)
	_catalog_button.name = "CatalogRune"
	_catalog_button.tooltip_text = "Pilih animasi (%d klip)" % Catalog.clip_count()
	layer.add_child(_catalog_button)
	_place(_catalog_button, Control.PRESET_TOP_RIGHT, -88, 20)
	_catalog_button.pressed.connect(_toggle_panel)
	# --- kanan bawah: serang besar + tombol aksi di sekelilingnya -----------
	_attack = _rune("SERANG", ATTACK_DIAMETER, SWORD_ICON)
	_attack.name = "AttackRune"
	_attack.tooltip_text = "Ayunan pedang; tap lagi setelah serangan selesai"
	layer.add_child(_attack)
	# Serang sengaja TIDAK di pojok: dulu pas di sudut layar dan susah ditekan
	# dengan ibu jari. Sekarang tombolnya berhenti ±130-200 px dari tepi
	# kanan/bawah (zona nyaman ibu jari), dan tombol lain disebar melengkung di
	# sekitarnya dengan jarak lega supaya tidak salah pencet.
	# BATASAN: posisi ditulis sebagai offset piksel dari pojok kanan-bawah, dan
	# CI menguji HUD di 640x360 sementara HP memakai 1280x720. Jadi offset
	# vertikal dibatasi ±300 px supaya TENGAH setiap tombol tetap masuk layar di
	# kedua ukuran (tes menyentuh tombol pada titik tengahnya).
	_place(_attack, Control.PRESET_BOTTOM_RIGHT, -200, -200)
	_register_hud_control("Serang", _attack, ATTACK_DIAMETER, -200, -200)
	_attack.pressed.connect(_attack_action)
	_fire_button = _rune("TEMBAK", FIRE_DIAMETER, FIRE_ICON)
	_fire_button.name = "FireRune"
	_fire_button.tooltip_text = "Tembakan api pet"
	layer.add_child(_fire_button)
	_place(_fire_button, Control.PRESET_BOTTOM_RIGHT, -360, -180)
	_register_hud_control("Tembak", _fire_button, FIRE_DIAMETER, -360, -180)
	_fire_button.pressed.connect(_fire_action)
	_jump = _rune("LOMPAT", ACTION_DIAMETER, JUMP_ICON)
	_jump.name = "JumpRune"
	layer.add_child(_jump)
	_place(_jump, Control.PRESET_BOTTOM_RIGHT, -196, -300)
	_register_hud_control("Lompat", _jump, ACTION_DIAMETER, -196, -300)
	_jump.pressed.connect(_player.request_jump)
	_crouch = _rune("JONGKOK", ACTION_DIAMETER, CROUCH_ICON)
	_crouch.name = "CrouchRune"
	layer.add_child(_crouch)
	_place(_crouch, Control.PRESET_BOTTOM_RIGHT, -470, -180)
	_register_hud_control("Jongkok", _crouch, ACTION_DIAMETER, -470, -180)
	_crouch.pressed.connect(_toggle_crouch)
	_speed_button = SpeedButton.new()
	_speed_button.name = "SpeedBoost"
	_speed_button.caption = "LARI"
	_speed_button.tooltip_text = "Lari kencang ×1,35 / normal"
	# Ukuran WAJIB diisi: tanpa custom_minimum_size, _place() menghitung diameter
	# 0 dan tombol ini jadi nol piksel (tidak bisa ditekan sama sekali).
	_speed_button.custom_minimum_size = Vector2(SPEED_DIAMETER, SPEED_DIAMETER)
	layer.add_child(_speed_button)
	_place(_speed_button, Control.PRESET_BOTTOM_RIGHT, -460, -300)
	_register_hud_control("Lari", _speed_button, SPEED_DIAMETER, -460, -300)
	_speed_button.pressed.connect(_toggle_speed)
	# Dash: dorongan lurus 12 m/s dengan animasi lari diperlambat satu langkah.
	# Ditaruh di atas tombol serang, mudah dijangkau.
	_dash = _rune("DASH", DASH_DIAMETER, DASH_ICON)
	_dash.name = "DashRune"
	_dash.tooltip_text = "Dash: menerjang lurus sebentar"
	layer.add_child(_dash)
	_place(_dash, Control.PRESET_BOTTOM_RIGHT, -330, -300)
	_register_hud_control("Dash", _dash, DASH_DIAMETER, -330, -300)
	_dash.pressed.connect(_dash_action)
	_build_graphics_drawer(layer)
	_build_layout_editor(layer)
	_load_hud_layout()
	_panel = AnimationPanel.new()
	_panel.character = _visual
	layer.add_child(_panel)
	_panel.closed.connect(_close_panel)
	# Analog tidak boleh ikut aktif saat tombol HUD ditekan.
	_joystick.input_exclusions = [_survival_panel, _panel, _graphics_drawer, _layout_editor, _settings,
		_layout_button, _catalog_button, _attack, _fire_button, _jump, _crouch,
		_speed_button, _dash]
	_orbit.exclusions = [_survival_panel, _panel, _graphics_drawer, _layout_editor, _settings,
		_layout_button, _catalog_button, _attack, _fire_button, _jump, _crouch,
		_speed_button, _dash]
	_npc_interaction = NPCInteraction.new()
	_npc_interaction.player = _player
	_npc_interaction.npc = _npc
	_npc_interaction.joystick = _joystick
	_npc_interaction.orbit = _orbit
	_npc_interaction.canvas_layer = layer
	_npc_interaction.controls_to_hide = [
		_joystick, _banner, _settings, _layout_button, _catalog_button, _attack,
		_fire_button, _jump, _crouch, _speed_button, _dash, _panel,
		_graphics_drawer, _layout_editor,
	]
	add_child(_npc_interaction)
	_npc_interaction.gameplay_requested.connect(_show_mode_selector)
	_mode_selector = ModeSelector.new()
	layer.add_child(_mode_selector)
	_mode_selector.mode_selected.connect(_on_mode_selected)
	_mode_selector.closed.connect(_on_mode_selector_closed)


func _rune(caption: String, diameter: float, glyph: Texture2D = null) -> RuneButton:
	# Semua tombol aksi bulat — tidak ada kotak di HUD.
	var button := RuneButton.new()
	button.caption = caption
	button.glyph = glyph
	button.custom_minimum_size = Vector2(diameter, diameter)
	return button


func _place(control: Control, preset: int, left: float, top: float) -> void:
	var diameter := maxf(control.custom_minimum_size.x, control.custom_minimum_size.y)
	control.set_anchors_and_offsets_preset(preset)
	control.offset_left = left
	control.offset_top = top
	control.offset_right = left + diameter
	control.offset_bottom = top + diameter


func _build_graphics_drawer(layer: CanvasLayer) -> void:
	_graphics_drawer = PanelContainer.new()
	_graphics_drawer.name = "GraphicsDrawer"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.025, 0.03, 0.78)
	style.border_color = Color(1, 1, 1, 0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(18)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	_graphics_drawer.add_theme_stylebox_override("panel", style)
	layer.add_child(_graphics_drawer)
	_graphics_drawer.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_graphics_drawer.offset_left = -334
	_graphics_drawer.offset_right = -24
	_graphics_drawer.offset_top = 196
	_graphics_drawer.offset_bottom = 566
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	_graphics_drawer.add_child(content)
	var title := Label.new()
	title.text = "GRAFIK"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color.WHITE)
	content.add_child(title)
	_performance = PerformancePanel.new()
	_performance.sun = _sun
	_performance.grass = _grass
	_performance.character = _visual
	content.add_child(_performance)
	_graphics_drawer.hide()


func _build_layout_editor(layer: CanvasLayer) -> void:
	_layout_editor = PanelContainer.new()
	_layout_editor.name = "HUDLayoutEditor"
	_layout_editor.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.032, 0.045, 0.96)
	style.border_color = Color("b9a66a", 0.78)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_layout_editor.add_theme_stylebox_override("panel", style)
	layer.add_child(_layout_editor)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	_layout_editor.add_child(content)
	var title := Label.new()
	title.text = "TATA LETAK HUD"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("f4f0e7"))
	content.add_child(title)
	_layout_readout = Label.new()
	_layout_readout.add_theme_font_size_override("font_size", 11)
	_layout_readout.add_theme_color_override("font_color", Color("cfc6d4"))
	content.add_child(_layout_readout)
	_layout_target = OptionButton.new()
	_layout_target.name = "HUDButtonTarget"
	_layout_target.custom_minimum_size = Vector2(0, 36)
	_layout_target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layout_target.focus_mode = Control.FOCUS_NONE
	for button_name: String in ["Serang", "Tembak", "Lompat", "Jongkok", "Lari", "Dash"]:
		_layout_target.add_item(button_name)
	content.add_child(_layout_target)
	_layout_size = _make_layout_slider(content, "Ukuran tombol", 58.0, 200.0, 2.0)
	_layout_x = _make_layout_slider(content, "Geser dari kanan", 0.0, 0.75, 0.01)
	_layout_y = _make_layout_slider(content, "Geser dari bawah", 0.0, 0.75, 0.01)
	var hint := Label.new()
	hint.text = "Perubahan disimpan otomatis di perangkat ini."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color("aaa2b0"))
	content.add_child(hint)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)
	var reset := _layout_action_button("RESET", _reset_selected_hud_layout)
	var done := _layout_action_button("SELESAI", _toggle_layout_editor)
	actions.add_child(reset)
	actions.add_child(done)
	_layout_target.item_selected.connect(_on_layout_target_changed)
	_layout_size.value_changed.connect(_on_layout_value_changed)
	_layout_x.value_changed.connect(_on_layout_value_changed)
	_layout_y.value_changed.connect(_on_layout_value_changed)
	get_viewport().size_changed.connect(_layout_layout_editor)
	_layout_editor.hide()
	_layout_layout_editor()


func _make_layout_slider(parent: VBoxContainer, caption: String,
		minimum: float, maximum: float, step: float) -> HSlider:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("e1dbe5"))
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.custom_minimum_size = Vector2(0, 26)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)
	return slider


func _layout_action_button(caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(100, 38)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 11)
	button.add_theme_color_override("font_color", Color("f4f0e7"))
	button.add_theme_stylebox_override("normal", _progress_style(Color(0.16, 0.13, 0.20, 1)))
	button.add_theme_stylebox_override("hover", _progress_style(Color(0.27, 0.22, 0.32, 1)))
	button.pressed.connect(action)
	return button


func _register_hud_control(button_name: String, control: Control, size: float,
		left: float, top: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var entry := {
		"size": size,
		"x": absf(left) / maxf(viewport_size.x, 1.0),
		"y": absf(top) / maxf(viewport_size.y, 1.0),
	}
	_hud_controls[button_name] = control
	_hud_layout_defaults[button_name] = entry.duplicate(true)
	_hud_layout[button_name] = entry.duplicate(true)


func _load_hud_layout() -> void:
	var config := ConfigFile.new()
	if config.load("user://hud_layout.cfg") == OK:
		for button_name: String in _hud_layout:
			var entry: Dictionary = _hud_layout[button_name]
			entry["size"] = float(config.get_value("buttons", button_name + "_size", entry["size"]))
			entry["x"] = float(config.get_value("buttons", button_name + "_x", entry["x"]))
			entry["y"] = float(config.get_value("buttons", button_name + "_y", entry["y"]))
	for button_name: String in _hud_controls:
		_apply_hud_control(button_name)
	_update_layout_sliders(0)
	get_viewport().size_changed.connect(_apply_all_hud_layout)


func _save_hud_layout() -> void:
	var config := ConfigFile.new()
	for button_name: String in _hud_layout:
		var entry: Dictionary = _hud_layout[button_name]
		config.set_value("buttons", button_name + "_size", entry["size"])
		config.set_value("buttons", button_name + "_x", entry["x"])
		config.set_value("buttons", button_name + "_y", entry["y"])
	config.save("user://hud_layout.cfg")


func _apply_all_hud_layout() -> void:
	for button_name: String in _hud_controls:
		_apply_hud_control(button_name)
	if _layout_target != null:
		_update_layout_sliders(_layout_target.selected)


func _apply_hud_control(button_name: String) -> void:
	if not _hud_controls.has(button_name) or not _hud_layout.has(button_name):
		return
	var control := _hud_controls[button_name] as Control
	if control == null:
		return
	var entry: Dictionary = _hud_layout[button_name]
	var view := get_viewport().get_visible_rect().size
	var size := clampf(float(entry["size"]), 58.0, 200.0)
	var max_x := maxf((view.x - size) / maxf(view.x, 1.0), 0.0)
	var max_y := maxf((view.y - size) / maxf(view.y, 1.0), 0.0)
	var x_fraction := clampf(float(entry["x"]), 0.0, max_x)
	var y_fraction := clampf(float(entry["y"]), 0.0, max_y)
	entry["size"] = size
	entry["x"] = x_fraction
	entry["y"] = y_fraction
	control.custom_minimum_size = Vector2(size, size)
	control.offset_left = -view.x * x_fraction
	control.offset_top = -view.y * y_fraction
	control.offset_right = control.offset_left + size
	control.offset_bottom = control.offset_top + size


func _update_layout_sliders(index: int) -> void:
	if _layout_target == null or _layout_size == null or _layout_x == null or _layout_y == null:
		return
	if index < 0 or index >= _layout_target.item_count:
		return
	var button_name := _layout_target.get_item_text(index)
	if not _hud_layout.has(button_name):
		return
	var entry: Dictionary = _hud_layout[button_name]
	var view := get_viewport().get_visible_rect().size
	var size := float(entry["size"])
	_layout_suppress = true
	_layout_size.value = size
	_layout_x.max_value = maxf((view.x - size) / maxf(view.x, 1.0), 0.0)
	_layout_y.max_value = maxf((view.y - size) / maxf(view.y, 1.0), 0.0)
	_layout_x.value = float(entry["x"])
	_layout_y.value = float(entry["y"])
	_layout_readout.text = "%s  ·  %d px" % [button_name, roundi(size)]
	_layout_suppress = false


func _on_layout_target_changed(index: int) -> void:
	_update_layout_sliders(index)


func _on_layout_value_changed(_value: float) -> void:
	if _layout_suppress or _layout_target == null:
		return
	var button_name := _layout_target.get_item_text(_layout_target.selected)
	if not _hud_layout.has(button_name):
		return
	_hud_layout[button_name] = {
		"size": _layout_size.value,
		"x": _layout_x.value,
		"y": _layout_y.value,
	}
	_apply_hud_control(button_name)
	_update_layout_sliders(_layout_target.selected)
	_save_hud_layout()


func _reset_selected_hud_layout() -> void:
	if _layout_target == null:
		return
	var button_name := _layout_target.get_item_text(_layout_target.selected)
	if not _hud_layout_defaults.has(button_name):
		return
	_hud_layout[button_name] = _hud_layout_defaults[button_name].duplicate(true)
	_apply_hud_control(button_name)
	_update_layout_sliders(_layout_target.selected)
	_save_hud_layout()


func _layout_layout_editor() -> void:
	if _layout_editor == null:
		return
	var view := get_viewport().get_visible_rect().size
	var width := minf(344.0, view.x - 20.0)
	var height := minf(364.0, view.y - 20.0)
	_layout_editor.position = Vector2(view.x - width - 10.0, 10.0)
	_layout_editor.size = Vector2(maxf(width, 280.0), maxf(height, 300.0))


func _toggle_layout_editor() -> void:
	_layout_editor.visible = not _layout_editor.visible
	if _layout_editor.visible:
		_graphics_drawer.hide()
		_update_layout_sliders(_layout_target.selected)
	_apply_input_state()


# --------------------------------------------------------------- mode game --

func _show_mode_selector() -> void:
	if _active_mode != "hub" or _mode_selector == null:
		return
	_player.velocity = Vector3.ZERO
	_player.move_speed = 0.0
	if _npc_interaction != null:
		_npc_interaction.set_process(false)
		var prompt := _npc_interaction.get("_prompt") as Control
		if prompt != null:
			prompt.hide()
	_mode_selector.open()
	_apply_input_state()


func _on_mode_selected(mode: String) -> void:
	if mode == "survival":
		_enter_survival()


func _on_mode_selector_closed() -> void:
	if _active_mode == "hub" and _npc_interaction != null:
		_npc_interaction.set_process(true)
	_apply_input_state()


func _enter_survival() -> void:
	if _active_mode != "hub":
		return
	_active_mode = "survival"
	if _npc_interaction != null:
		_npc_interaction.npc = null
		_npc_interaction.set_process(false)
		_npc_interaction.set_physics_process(false)
	if is_instance_valid(_npc):
		_npc.queue_free()
	if is_instance_valid(_forest):
		_forest.queue_free()
	if is_instance_valid(_scenery):
		_scenery.queue_free()
	if is_instance_valid(_field):
		_field.queue_free()
	_npc = null
	_forest = null
	_scenery = null
	_field = null
	_player.global_position = Vector3.ZERO
	_survival_world = SurvivalWorld.new()
	_survival_world.player = _player
	add_child(_survival_world)
	_player.field = _survival_world.ground
	_player.world_bounds_enabled = false
	_player.boosted = false
	_player.crouching = false
	_player.dashing = false
	_player.spawn(Vector2.ZERO)
	_player.reset_health()
	_player.set_sword_mode(true)
	_player.attack_started.connect(_on_player_attack_started)
	_survival_world.status_changed.connect(_update_survival_status)
	_footsteps.field = _survival_world.ground
	_foot_fire.field = _survival_world.ground
	_grass.set_ground(_survival_world.ground)
	_survival_panel.show()
	_update_survival_status(0.0, _survival_world.zombies.size(), 0)
	_on_health_changed(_player.health)
	print("[main] mode Survival siap; tanah tak berbatas + zombie UAL aktif")


func _on_player_attack_started(clip: String) -> void:
	if _survival_world != null and is_instance_valid(_survival_world):
		_survival_world.resolve_player_attack(clip)


func _update_survival_status(elapsed: float, living: int, defeated: int) -> void:
	if _survival_status == null:
		return
	var total_seconds := int(elapsed)
	_survival_status.text = "%02d:%02d · ZOMBI %02d · KALAH %d" % [
		int(total_seconds / 60), total_seconds % 60, living, defeated]


func _on_health_changed(value: int) -> void:
	if _health_bar == null:
		return
	_health_bar.value = value
	_health_text.text = "HP %d" % value
	var fill_color := Color("cf705c") if value <= 30 else Color("8cc46a")
	_health_bar.add_theme_stylebox_override("fill", _progress_style(fill_color))


# --------------------------------------------------------------- aksi HUD --

func _attack_action() -> void:
	_player.attack()


func _fire_action() -> void:
	_pet.attack()


func _toggle_speed() -> void:
	_player.toggle_boost()
	_speed_button.boosted = _player.boosted
	_speed_button.queue_redraw()


func _dash_action() -> void:
	_player.request_dash()


func _toggle_crouch() -> void:
	_player.toggle_crouch()
	_crouch.caption = "BERDIRI" if _player.crouching else "JONGKOK"
	_crouch.queue_redraw()


func _toggle_panel() -> void:
	if _panel.visible:
		_panel.close_panel()
	else:
		_panel.open()
	_apply_input_state()


func _close_panel() -> void:
	_apply_input_state()


func _toggle_graphics() -> void:
	if _graphics_drawer.visible:
		_graphics_drawer.hide()
	else:
		_layout_editor.hide()
		_graphics_drawer.show()
	_apply_input_state()


func _apply_input_state() -> void:
	var selector_open := _mode_selector != null and _mode_selector.visible
	var layout_open := _layout_editor != null and _layout_editor.visible
	var hide_actions := _panel.visible or _graphics_drawer.visible or selector_open
	var overlay := hide_actions or layout_open
	_joystick.reset()
	_joystick.input_enabled = not overlay
	_orbit.reset_touches()
	_orbit.input_enabled = not overlay
	_settings.visible = not selector_open
	_layout_button.visible = not selector_open
	for control: Control in [_attack, _fire_button, _jump, _crouch, _speed_button, _dash]:
		control.visible = not hide_actions
		control.set("disabled", layout_open)
	_catalog_button.visible = not _graphics_drawer.visible and not layout_open and not selector_open
	_banner.visible = not overlay


func _input(event: InputEvent) -> void:
	if not _graphics_drawer.visible and not _layout_editor.visible:
		return
	var point := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		point = event.position
	elif event is InputEventMouseButton and event.pressed:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		point = event.position
	else:
		return
	if _graphics_drawer.visible and not _graphics_drawer.get_global_rect().has_point(point) \
			and not _settings.contains_point(point):
		_toggle_graphics()
	elif _layout_editor.visible and not _layout_editor.get_global_rect().has_point(point) \
			and not _layout_button.contains_point(point):
		_toggle_layout_editor()


# ----------------------------------------------------------------- loop ----

func _physics_process(delta: float) -> void:
	if _orbit == null or _player == null:
		return
	_orbit.follow(_player.global_position + _orbit.focus_offset, delta)
	_footsteps.update_motion(delta, _player.move_speed)
	# Efek kecepatan: pita jejak + asap + bloom layar. `_player.dashing` membuat
	# efeknya jauh lebih kuat saat dash daripada saat sekadar boost.
	_speed_aura.update_motion(delta, _player.move_speed,
		_player.boosted and _player.grounded)
	_update_dash_bloom(delta)


## Pancaran bloom pada KARAKTER saat dash (permintaan ronde 18: "efek blur/glow
## di karakter, bukan hanya setelah gambar"). Kulit menyala di pinggir siluet
## dengan warna yang melewati ambang glow, jadi benar-benar mekar, lalu memudar
## perlahan sesudah dash selesai.
func _update_dash_bloom(delta: float) -> void:
	if _visual == null or _visual.skin == null:
		return
	var wanted := 0.0
	if _player != null and _player.dashing:
		wanted = 1.0
	elif _player != null and _player.boosted and _player.grounded and _player.move_speed > 0.3:
		# Saat boost biasa bloom-nya tipis saja — dash yang harus terasa jelas.
		wanted = 0.25
	var speed := 14.0 if wanted > _bloom_level else 5.0
	_bloom_level = lerpf(_bloom_level, wanted, 1.0 - exp(-delta * speed))
	if _bloom_level < 0.004 and wanted == 0.0:
		_bloom_level = 0.0
	_visual.skin.set_bloom(_bloom_level)


func _process(_delta: float) -> void:
	_fire_button.cooldown_fraction = clampf(_pet.cooldown / FirePet.COOLDOWN, 0, 1)
	_fire_button.queue_redraw()
	# Sapuan cooldown dash: busur mengikuti sisa waktu tunggu.
	_dash.cooldown_fraction = clampf(_player.dash_cooldown / Player.DASH_COOLDOWN, 0, 1)
	_dash.queue_redraw()
	if _speed_button.boosted != _player.boosted:
		_speed_button.boosted = _player.boosted
		_speed_button.queue_redraw()


func _confirm_boot() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	# Jejak untuk mendiagnosis "aplikasi berhenti": kalau baris ini tidak pernah
	# muncul, masalahnya terjadi sebelum gameplay benar-benar siap.
	_write_boot_marker()


func _write_boot_marker() -> void:
	var file := FileAccess.open(BOOT_TRACE, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(BOOT_TRACE, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line("%s %s" % [Time.get_datetime_string_from_system(false, true), BOOT_READY])
	file.close()
	# Produksi saja; tes terisolasi memakai alurnya sendiri.
	if DisplayServer.get_name() != "headless" and (
			get_tree().current_scene == self or warmup_requested):
		var warmup := ShaderWarmup.new()
		add_child(warmup)
		warmup_report = await warmup.run(self)
		warmup.queue_free()
	warmup_complete = true
	# Launcher memakai marker ini untuk mendeteksi boot konten yang terputus.
	DirAccess.remove_absolute("user://content_boot_pending")


func _exit_tree() -> void:
	get_viewport().use_occlusion_culling = _previous_occlusion
