extends Node3D
## Padang rumput 100 m × 100 m + mannequin UAL berkulit beranimasi yang
## digerakkan katalog animasi lengkap (85 klip UAL1 + UAL2) lewat retarget, plus
## goyangan kain/rambut simulasi verlet.

const Field = preload("res://src/game/world/field.gd")
const Scenery = preload("res://src/game/world/scenery.gd")
const Fence = preload("res://src/game/world/boundary_fence.gd")
const Grass = preload("res://src/game/grass_field.gd")
const Player = preload("res://src/game/player.gd")
const Character = preload("res://src/game/mannequin.gd")
const Orbit = preload("res://src/game/orbit_camera.gd")
const Joystick = preload("res://src/game/virtual_joystick.gd")
const Night = preload("res://src/game/environment/night_environment.gd")
const MoonRays = preload("res://src/game/god_rays/moon_rays.gd")
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
const SPAWN := Vector2(0, 7)
## HUD gaya game aksi: satu tombol serang besar, tombol aksi bulat di sekitarnya.
const ATTACK_DIAMETER := 136.0
const FIRE_DIAMETER := 96.0
const ACTION_DIAMETER := 92.0
const RUNE_DIAMETER := 72.0

var warmup_requested := false
var warmup_complete := false
var warmup_report: Dictionary = {}
var _previous_occlusion := false
var _field: Field
var _scenery: Scenery
var _grass: Grass
var _player: Player
var _visual: Character
var _orbit: Orbit
var _sun: DirectionalLight3D
var _moon_rays: MoonRays
var _audio: WorldAudio
var _footsteps: Footsteps
var _foot_fire: FootFire
var _speed_aura: SpeedAura
var _pet: FirePet
var _joystick: Joystick
var _attack: RuneButton
var _fire_button: RuneButton
var _settings: RuneButton
var _speed_button: SpeedButton
var _jump: Button
var _crouch: Button
var _catalog_button: Button
var _banner: ClipBanner
var _panel: AnimationPanel
var _performance: PerformancePanel
var _graphics_drawer: PanelContainer


func _ready() -> void:
	_previous_occlusion = get_viewport().use_occlusion_culling
	get_viewport().use_occlusion_culling = true
	_build_environment()
	_build_world()
	_build_player()
	_build_camera()
	_build_grass()
	_build_effects()
	_build_hud()
	print("[main] padang %.0f m + mannequin (%d klip) siap" % [
		Field.SIZE, Catalog.clip_count()])
	_confirm_boot.call_deferred()


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "NightEnvironment"
	world_environment.environment = Night.make_environment()
	add_child(world_environment)
	_sun = Night.make_moonlight()
	add_child(_sun)
	_sun.look_at_from_position(Vector3.ZERO, -Night.MOON_DIRECTION)


func _build_world() -> void:
	_field = Field.new()
	add_child(_field)
	# Pemandangan di luar pagar: bukit, tebing, laut, reruntuhan batu, titik
	# cahaya — disusun seperti ilustrasi layar muat. Tanpa collision, jadi
	# gameplay di dalam padang tidak berubah.
	_scenery = Scenery.new()
	add_child(_scenery)
	add_child(Fence.new())


func _build_player() -> void:
	_player = Player.new()
	_player.field = _field
	add_child(_player)
	_visual = Character.new()
	_visual.name = "Visual"
	_visual.position.y = -Player.HEIGHT * 0.5
	_player.add_child(_visual)
	_player.visual = _visual
	_player.spawn(SPAWN)


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
	_moon_rays = MoonRays.new()
	_moon_rays.camera = _orbit.camera
	_orbit.camera.add_child(_moon_rays)
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
	_speed_aura.environment = get_node("NightEnvironment").environment
	add_child(_speed_aura)
	_pet = FirePet.new()
	_pet.player = _player
	_pet.facing = _visual
	_pet.camera = _orbit.camera
	_pet.cast_started.connect(_visual.start_cast)
	add_child(_pet)
	_audio.follow_fire(_pet)


# ------------------------------------------------------------------ HUD ----

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_joystick = Joystick.new()
	layer.add_child(_joystick)
	_joystick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_player.joystick = _joystick
	_banner = ClipBanner.new()
	_banner.character = _visual
	_banner.extra = "geser kiri = jalan/lari · SERANG = combo · TEMBAK = api"
	layer.add_child(_banner)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_banner.offset_left = 20
	_banner.offset_top = 20
	# --- sudut kanan atas: dua tombol kecil bulat ---------------------------
	_settings = _rune("GRAFIK", RUNE_DIAMETER, SETTINGS_ICON)
	_settings.name = "GraphicsRune"
	_settings.compact = true
	_settings.tooltip_text = "Pengaturan grafik"
	layer.add_child(_settings)
	_place(_settings, Control.PRESET_TOP_RIGHT, -92, 104)
	_settings.pressed.connect(_toggle_graphics)
	_catalog_button = _rune("ANIM", RUNE_DIAMETER)
	_catalog_button.name = "CatalogRune"
	_catalog_button.tooltip_text = "Pilih animasi (%d klip)" % Catalog.clip_count()
	layer.add_child(_catalog_button)
	_place(_catalog_button, Control.PRESET_TOP_RIGHT, -92, 20)
	_catalog_button.pressed.connect(_toggle_panel)
	# --- kanan bawah: serang besar + tombol aksi di sekelilingnya -----------
	_attack = _rune("SERANG", ATTACK_DIAMETER)
	_attack.name = "AttackRune"
	_attack.tooltip_text = "Serangan combo: tekan berulang untuk lanjut"
	layer.add_child(_attack)
	_place(_attack, Control.PRESET_BOTTOM_RIGHT, -172, -172)
	_attack.pressed.connect(_attack_action)
	_fire_button = _rune("TEMBAK", FIRE_DIAMETER, FIRE_ICON)
	_fire_button.name = "FireRune"
	_fire_button.tooltip_text = "Tembakan api pet"
	layer.add_child(_fire_button)
	_place(_fire_button, Control.PRESET_BOTTOM_RIGHT, -300, -176)
	_fire_button.pressed.connect(_fire_action)
	_jump = _rune("LOMPAT", ACTION_DIAMETER)
	_jump.name = "JumpRune"
	layer.add_child(_jump)
	_place(_jump, Control.PRESET_BOTTOM_RIGHT, -152, -300)
	_jump.pressed.connect(_player.request_jump)
	_crouch = _rune("JONGKOK", ACTION_DIAMETER)
	_crouch.name = "CrouchRune"
	layer.add_child(_crouch)
	_place(_crouch, Control.PRESET_BOTTOM_RIGHT, -354, -292)
	_crouch.pressed.connect(_toggle_crouch)
	_speed_button = SpeedButton.new()
	_speed_button.name = "SpeedBoost"
	_speed_button.caption = "LARI"
	_speed_button.tooltip_text = "Lari kencang ×1,35 / normal"
	layer.add_child(_speed_button)
	_place(_speed_button, Control.PRESET_BOTTOM_RIGHT, -260, -300)
	_speed_button.pressed.connect(_toggle_speed)
	_build_graphics_drawer(layer)
	_panel = AnimationPanel.new()
	_panel.character = _visual
	layer.add_child(_panel)
	_panel.closed.connect(_close_panel)
	# Analog tidak boleh ikut aktif saat tombol HUD ditekan.
	_joystick.input_exclusions = [_panel, _graphics_drawer, _settings, _catalog_button,
		_attack, _fire_button, _jump, _crouch, _speed_button]
	_orbit.exclusions = [_panel, _graphics_drawer, _settings, _catalog_button,
		_attack, _fire_button, _jump, _crouch, _speed_button]


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
	_performance.rays = _moon_rays
	_performance.sun = _sun
	_performance.grass = _grass
	_performance.character = _visual
	content.add_child(_performance)
	_graphics_drawer.hide()


# --------------------------------------------------------------- aksi HUD --

func _attack_action() -> void:
	_player.attack()


func _fire_action() -> void:
	_pet.attack()


func _toggle_speed() -> void:
	_player.toggle_boost()
	_speed_button.boosted = _player.boosted
	_speed_button.queue_redraw()


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
	_graphics_drawer.visible = not _graphics_drawer.visible
	_apply_input_state()


func _apply_input_state() -> void:
	var overlay := _panel.visible or _graphics_drawer.visible
	_joystick.reset()
	_joystick.input_enabled = not overlay
	_orbit.reset_touches()
	_orbit.input_enabled = not overlay
	_attack.visible = not overlay
	_fire_button.visible = not overlay
	_jump.visible = not overlay
	_crouch.visible = not overlay
	_speed_button.visible = not overlay
	_catalog_button.visible = not _graphics_drawer.visible
	_banner.visible = not overlay


func _input(event: InputEvent) -> void:
	if not _graphics_drawer.visible:
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
	if not _graphics_drawer.get_global_rect().has_point(point) \
			and not _settings.contains_point(point):
		_toggle_graphics()


# ----------------------------------------------------------------- loop ----

func _physics_process(delta: float) -> void:
	if _orbit == null or _player == null:
		return
	_orbit.follow(_player.global_position + _orbit.focus_offset, delta)
	_footsteps.update_motion(delta, _player.move_speed)
	_speed_aura.update_motion(delta, _player.move_speed,
		_player.boosted and _player.grounded)


func _process(_delta: float) -> void:
	_fire_button.cooldown_fraction = clampf(_pet.cooldown / FirePet.COOLDOWN, 0, 1)
	_fire_button.queue_redraw()
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
