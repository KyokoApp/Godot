extends SceneTree
## Render selector Gameplay/Survival dan gameplay dunia datar untuk regresi visual Mobile Vulkan.

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
	print("::error::", message)


func _run() -> void:
	var game := load("res://src/game/main.tscn").instantiate() as Node3D
	root.add_child(game)
	var hub_player := game.get("_player") as CharacterBody3D
	for _frame in range(75):
		await physics_frame
		if hub_player.is_on_floor():
			break
	var selector: Control = game.get("_mode_selector")
	_check(selector != null, "Selector mode tidak ditemukan")
	if selector == null:
		quit(1)
		return
	selector.call("open")
	game.call("_apply_input_state")
	for _frame in range(36):
		await process_frame
	var cards: Array = selector.get("_cards")
	_check(cards.size() == 3, "Selector mode tidak menampilkan tiga pilihan")
	await _capture("survival-mode-selector")
	selector.call("close")
	for _frame in range(20):
		await physics_frame
	game.call("_enter_survival")
	var player: CharacterBody3D = game.get("_player")
	var visual: Node3D = game.get("_visual")
	var world: Node = game.get("_survival_world")
	_check(world != null, "Mode Survival tidak membuat dunianya")
	if world == null:
		quit(1)
		return
	var weapon := visual.get("weapon_instance") as Node3D
	_check(not bool(player.get("sword_mode")), "Mode Survival masih mengaktifkan pedang")
	_check(weapon == null or not weapon.visible, "Pedang masih terlihat di Survival")
	var joystick: Control = game.get("_joystick")
	_check(joystick != null and joystick.visible,
		"HUD analog-only tidak menampilkan joystick")
	for node_name in ["_attack", "_fire_button", "_jump", "_crouch", "_speed_button", "_dash"]:
		var action_button: Control = game.get(node_name)
		_check(action_button != null and not action_button.is_visible_in_tree()
			and bool(action_button.get("disabled")),
			"HUD Survival masih menampilkan tombol gameplay: " + node_name)
	var orbit: Node3D = game.get("_orbit")
	_check(float(orbit.get("pitch")) >= 1.25,
		"Render Survival tidak memakai sudut kamera top-down")
	_check(int(world.get("stage")) == 1,
		"Gameplay Survival render tidak mulai dari stage 1")
	orbit.set("yaw", 0.0)
	orbit.set("distance", 17.0)
	orbit.set("exclusions", [])
	for node_name in ["_pet", "_speed_aura", "_foot_fire", "_banner"]:
		var effect: Node = game.get(node_name)
		if effect != null:
			effect.set("visible", false)
			effect.set_process(false)
	var zombies: Array = world.get("zombies")
	_check(zombies.size() >= 3, "Zombie awal tidak tampil di render")
	for index in zombies.size():
		var zombie: Node3D = zombies[index] as Node3D
		zombie.global_position = Vector3((index - 1) * 3.2, 0.9, -9.0 - float(index) * 1.2)
		var zombie_visual := zombie.get("visual") as Node3D
		zombie_visual.rotation.y = 0.0
	for _frame in range(100):
		await physics_frame
	await _capture("survival-world")
	var buff_system: Node = world.get("buff_system")
	var choices: Array = buff_system.call("available_choices", 3)
	world.set("_pending_buff_choices", 1)
	world.set("_awaiting_buff_choice", true)
	var survival_hud: Control = game.get("_survival_hud")
	survival_hud.call("show_buff_choices", world, choices, 5)
	for _frame in range(24):
		await process_frame
	await _capture("survival-buff-choice")
	survival_hud.call("_finish_buff_choice", str(choices[0].get("id", "")))
	for _frame in range(3):
		await physics_frame
	print("[survival-render-test] zombies=", zombies.size(),
		" auto-fire=aktif, analog=aktif",
		" pedang=", "terlihat" if weapon != null and weapon.visible else "hilang")
	print("[survival-render-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	game.queue_free()
	for _frame in range(4):
		await process_frame
	quit(0 if _failures == 0 else 1)


func _capture(name: String) -> void:
	for _frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "user://%s-test.png" % name
	image.save_png(path)
	print("[survival-render-test] ", path, " ", image.get_width(), "x", image.get_height())
