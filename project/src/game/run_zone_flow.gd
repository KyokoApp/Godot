extends RefCounted
## Integrasi Run Zone dengan pemain/camera/HUD home; main.gd hanya mendelegasikan.

const Player = preload("res://src/game/player.gd")
const Orbit = preload("res://src/game/orbit_camera.gd")
const RunZoneWorld = preload("res://src/game/world/run_zone.gd")
const RunZoneHUD = preload("res://src/game/ui/run_zone_hud.gd")
const Joystick = preload("res://src/game/virtual_joystick.gd")

var _home_camera_fov := 65.0
var _environment_state: Dictionary = {}


func build_hud(layer: CanvasLayer, main: Node3D) -> RunZoneHUD:
	var hud := RunZoneHUD.new()
	layer.add_child(hud)
	hud.speed_pressed.connect(_on_speed_pressed.bind(main))
	hud.hide()
	return hud


func handle_back_event(main: Node3D, event: InputEvent, home_spawn: Vector2) -> bool:
	if str(main.get("_active_mode")) != "run_zone":
		return false
	if bool((main.get("_graphics_drawer") as Control).visible) \
			or bool((main.get("_layout_editor") as Control).visible):
		return false
	if not event is InputEventKey:
		return false
	var key := event as InputEventKey
	if not key.pressed or key.echo \
			or (key.keycode != KEY_ESCAPE and key.keycode != KEY_BACK):
		return false
	return_home(main, home_spawn)
	return true


func enter(main: Node3D) -> void:
	if str(main.get("_active_mode")) != "hub":
		return
	var orbit := main.get("_orbit") as Orbit
	var player := main.get("_player") as Player
	main.set("_home_camera_state", orbit.capture_state())
	_home_camera_fov = orbit.camera.fov if orbit.camera != null else 65.0
	_save_environment_state(main)
	main.set("_death_return_pending", false)
	main.set("_active_mode", "run_zone")
	main.set("_run_zone_intro_active", true)
	main.set("_survival_auto_fire_left", 0.0)

	var fire_button := main.get("_fire_button") as Control
	fire_button.set("auto_repeat_interval", 0.0)
	fire_button.call("reset_touch")
	var pet := main.get("_pet") as Node3D
	pet.call("set_rapid_fire", false)
	pet.call("reset_survival_modifiers")
	pet.visible = false
	pet.set_process(false)
	pet.set_physics_process(false)
	(main.get("_speed_aura") as Node).call("clear")

	var interaction := main.get("_npc_interaction") as Node
	interaction.set("npc", null)
	interaction.set_process(false)
	interaction.set_physics_process(false)
	for property in ["_npc", "_forest", "_scenery", "_field"]:
		var old_world_part := main.get(property) as Node
		if is_instance_valid(old_world_part):
			old_world_part.queue_free()
		main.set(property, null)

	player.end_endless_run()
	player.world_bounds_enabled = false
	player.boosted = false
	player.crouching = false
	player.dashing = false
	player.clear_survival_bonuses()
	player.set_sword_mode(false)
	player.field = null
	player.global_position = Vector3.ZERO

	var run_zone := RunZoneWorld.new()
	run_zone.player = player
	main.add_child(run_zone)
	main.set("_run_zone", run_zone)
	player.field = run_zone.ground
	player.spawn(Vector2.ZERO)
	player.reset_health()
	run_zone.intro_finished.connect(_on_intro_finished.bind(main))
	run_zone.run_started.connect(_on_run_started.bind(main))
	run_zone.progress_changed.connect(_on_progress.bind(main))
	run_zone.speed_level_changed.connect(_on_speed_level_changed.bind(main))
	run_zone.black_flash_reached.connect(_on_black_flash_reached.bind(main))
	run_zone.hollow_purple_impact.connect(_on_hollow_purple_impact.bind(main))
	var speed_control := (main.get("_run_zone_hud") as RunZoneHUD).speed_button
	var joystick := main.get("_joystick") as Joystick
	if not orbit.exclusions.has(speed_control):
		orbit.exclusions.append(speed_control)
	if not joystick.input_exclusions.has(speed_control):
		joystick.input_exclusions.append(speed_control)

	(main.get("_grass") as Node).call("set_ground", run_zone.ground)
	(main.get("_footsteps") as Node).set("field", run_zone.ground)
	var foot_fire := main.get("_foot_fire") as Node
	foot_fire.set("field", run_zone.ground)
	foot_fire.call("clear")
	(main.get("_survival_panel") as Control).hide()
	(main.get("_run_zone_hud") as RunZoneHUD).show_intro()

	orbit.set_run_zone_mode()
	# Mulai dari sisi depan agar perapal di belakang pemain masuk shot,
	# lalu putar melewati pemain ke kamera lari yang membidik arah jalur.
	orbit.yaw = PI
	orbit.pitch = Orbit.RUN_ZONE_MIN_PITCH
	orbit.distance = 6.4
	orbit.focus_offset = Vector3(0.0, 0.95, 0.0)
	orbit.global_position = player.global_position + orbit.focus_offset
	orbit.reset_touches()
	var old_tween := main.get("_run_zone_camera_tween") as Tween
	if old_tween != null and old_tween.is_running():
		old_tween.kill()
	var tween: Tween = main.create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.30)
	tween.tween_property(orbit, "yaw", 0.0, 1.25)
	tween.parallel().tween_property(orbit, "distance", 5.4, 1.25)
	tween.parallel().tween_property(orbit, "pitch", 0.27, 1.25)
	tween.parallel().tween_property(orbit, "focus_offset", Vector3(0.0, 0.58, 0.0), 1.25)
	main.set("_run_zone_camera_tween", tween)
	(main.get("_graphics_drawer") as Control).hide()
	(main.get("_layout_editor") as Control).hide()
	main.call("_apply_input_state")
	print("[main] Run Zone intro: penyihir terbang merapal, kamera beralih ke third-person")


func return_home(main: Node3D, home_spawn: Vector2) -> void:
	if str(main.get("_active_mode")) != "run_zone":
		return
	main.set("_run_zone_intro_active", false)
	var tween := main.get("_run_zone_camera_tween") as Tween
	if tween != null and tween.is_running():
		tween.kill()
	main.set("_run_zone_camera_tween", null)
	main.set("_active_mode", "hub")
	main.set("_survival_auto_fire_left", 0.0)
	var orbit := main.get("_orbit") as Orbit
	var joystick := main.get("_joystick") as Joystick
	var speed_control := (main.get("_run_zone_hud") as RunZoneHUD).speed_button
	orbit.exclusions.erase(speed_control)
	joystick.input_exclusions.erase(speed_control)
	var fire_button := main.get("_fire_button") as Control
	fire_button.set("auto_repeat_interval", 0.0)
	fire_button.call("reset_touch")
	var pet := main.get("_pet") as Node3D
	pet.call("set_rapid_fire", false)
	(main.get("_run_zone_hud") as RunZoneHUD).hide()

	var run_zone := main.get("_run_zone") as RunZoneWorld
	if is_instance_valid(run_zone):
		run_zone.finish_run()
		run_zone.queue_free()
	_restore_environment_state(main)
	main.set("_run_zone", null)
	var panel := main.get("_panel") as Control
	if panel.visible:
		panel.call("close_panel")
	(main.get("_graphics_drawer") as Control).hide()
	(main.get("_layout_editor") as Control).hide()
	(main.get("_mode_selector") as Control).hide()

	var camera_state: Dictionary = Dictionary(main.get("_home_camera_state"))
	orbit.restore_state(camera_state)
	if orbit.camera != null:
		orbit.camera.fov = _home_camera_fov
	var player := main.get("_player") as Player
	player.end_endless_run()
	player.world_bounds_enabled = true
	player.boosted = false
	player.crouching = false
	player.dashing = false
	player.global_position = Vector3.ZERO
	main.call("_build_world")
	var field := main.get("_field") as Node3D
	field.set("player", player)
	player.field = field
	player.spawn(home_spawn)
	player.reset_health()
	player.set_sword_mode(false)
	orbit.global_position = player.global_position + orbit.focus_offset

	var speed_button := main.get("_speed_button") as Control
	speed_button.set("boosted", false)
	speed_button.queue_redraw()
	var crouch_button := main.get("_crouch") as Control
	crouch_button.set("caption", "JONGKOK")
	crouch_button.queue_redraw()
	pet.visible = true
	pet.set_process(true)
	pet.set_physics_process(true)
	pet.call("reset_survival_modifiers")
	main.call("_build_npc")
	var interaction := main.get("_npc_interaction") as Node
	interaction.set("player", player)
	interaction.set("npc", main.get("_npc"))
	interaction.set_process(true)
	interaction.set_physics_process(true)
	var footsteps := main.get("_footsteps") as Node
	footsteps.set("field", field)
	var foot_fire := main.get("_foot_fire") as Node
	foot_fire.set("field", field)
	foot_fire.call("clear")
	(main.get("_grass") as Node).call("set_ground", field)
	(main.get("_survival_panel") as Control).hide()
	main.call("_apply_input_state")
	print("[main] Run Zone selesai; kembali ke home hub")


func _on_intro_finished(main: Node3D) -> void:
	if str(main.get("_active_mode")) != "run_zone":
		return
	var run_zone := main.get("_run_zone") as RunZoneWorld
	if is_instance_valid(run_zone):
		run_zone.start_run()


func _on_run_started(main: Node3D) -> void:
	if str(main.get("_active_mode")) != "run_zone":
		return
	main.set("_run_zone_intro_active", false)
	var run_zone := main.get("_run_zone") as RunZoneWorld
	(main.get("_run_zone_hud") as RunZoneHUD).show_running(
		run_zone.elapsed_seconds, run_zone.current_speed, run_zone.speed_level,
		run_zone.distance_m)
	main.call("_apply_input_state")
	print("[main] Run Zone dimulai; auto-run dan akselerasi bertahap aktif")


func _on_progress(elapsed_seconds: float, speed: float, speed_level: int,
		distance_m: float, main: Node3D) -> void:
	if str(main.get("_active_mode")) == "run_zone":
		(main.get("_run_zone_hud") as RunZoneHUD).show_running(
			elapsed_seconds, speed, speed_level, distance_m)


func _on_speed_pressed(main: Node3D) -> void:
	if str(main.get("_active_mode")) != "run_zone":
		return
	var run_zone := main.get("_run_zone") as RunZoneWorld
	if is_instance_valid(run_zone):
		run_zone.add_speed_level()


func _on_speed_level_changed(speed_level: int, speed: float, main: Node3D) -> void:
	if str(main.get("_active_mode")) != "run_zone":
		return
	var run_zone := main.get("_run_zone") as RunZoneWorld
	(main.get("_run_zone_hud") as RunZoneHUD).show_running(
		run_zone.elapsed_seconds, speed, speed_level, run_zone.distance_m)
	var orbit := main.get("_orbit") as Orbit
	if orbit.camera != null:
		orbit.camera.fov = lerpf(_home_camera_fov, 88.0,
			float(speed_level) / float(RunZoneWorld.SPEED_LEVEL_LIMIT))


func _on_black_flash_reached(main: Node3D) -> void:
	if str(main.get("_active_mode")) != "run_zone":
		return
	var world_environment := main.get_node_or_null("DuskEnvironment") as WorldEnvironment
	if world_environment != null and world_environment.environment != null:
		world_environment.environment.adjustment_enabled = true
		world_environment.environment.adjustment_saturation = 0.0
		world_environment.environment.adjustment_contrast = 1.06
		world_environment.environment.adjustment_brightness = 1.10
	(main.get("_run_zone_hud") as RunZoneHUD).play_black_flash()
	var orbit := main.get("_orbit") as Orbit
	orbit.combat_shake(0.15, 0.22)


func _on_hollow_purple_impact(position: Vector3, main: Node3D) -> void:
	if str(main.get("_active_mode")) != "run_zone":
		return
	(main.get("_run_zone_hud") as RunZoneHUD).play_hollow_purple_flash()
	var orbit := main.get("_orbit") as Orbit
	orbit.combat_shake(0.18, 0.42)
	print("[main] Hollow Purple menghantam jalur di ", position)


func _save_environment_state(main: Node3D) -> void:
	_environment_state.clear()
	var world_environment := main.get_node_or_null("DuskEnvironment") as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		return
	var environment := world_environment.environment
	_environment_state = {
		"adjustment_enabled": environment.adjustment_enabled,
		"saturation": environment.adjustment_saturation,
		"contrast": environment.adjustment_contrast,
		"brightness": environment.adjustment_brightness,
	}


func _restore_environment_state(main: Node3D) -> void:
	if _environment_state.is_empty():
		return
	var world_environment := main.get_node_or_null("DuskEnvironment") as WorldEnvironment
	if world_environment != null and world_environment.environment != null:
		var environment := world_environment.environment
		environment.adjustment_enabled = bool(_environment_state.get("adjustment_enabled", true))
		environment.adjustment_saturation = float(_environment_state.get("saturation", 1.0))
		environment.adjustment_contrast = float(_environment_state.get("contrast", 1.0))
		environment.adjustment_brightness = float(_environment_state.get("brightness", 1.0))
	_environment_state.clear()
