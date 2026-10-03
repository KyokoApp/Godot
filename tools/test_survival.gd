extends SceneTree
## Tes mode Survival: tanah tanpa batas, zombie UAL, pedang terpasang, dan input serang mandiri.

const Catalog = preload("res://src/game/animation/catalog.gd")

var _failures := 0


func _init() -> void:
	Engine.max_physics_steps_per_frame = 32
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
	for _frame in range(12):
		await physics_frame
	game.call("_enter_survival")
	for _frame in range(8):
		await physics_frame
	var player: CharacterBody3D = game.get("_player")
	var visual: Node3D = game.get("_visual")
	var world: Node = game.get("_survival_world")
	var selector: Control = game.get("_mode_selector")
	_check(str(game.get("_active_mode")) == "survival", "Mode Survival tidak aktif")
	_check(world != null, "Dunia Survival tidak dibuat")
	_check(selector != null and not selector.visible, "Selector mode menutupi gameplay")
	if world == null or player == null or visual == null:
		quit(1)
		return
	var ground: Node = world.get("ground")
	_check(ground != null, "Tanah datar Survival tidak dibuat")
	if ground != null:
		_check(is_zero_approx(float(ground.call("surface_height", 0.0, 0.0))),
			"Tanah Survival tidak datar")
		_check(bool(ground.call("can_grow", 1.0e6, -1.0e6)),
			"Tanah tanpa batas menolak rumput jauh")
		_check(bool(ground.call("allows_foot_effect", Vector3(1.0e6, 0, 0), 0.4)),
			"Tapak efek berhenti di batas dunia lama")
	_check(not bool(player.get("world_bounds_enabled")), "Batas pulau masih aktif di Survival")
	var far_point := Vector3(6000.0, 0.95, -9000.0)
	player.global_position = far_point
	player.call("_keep_inside")
	_check(Vector2(player.global_position.x, player.global_position.z).distance_to(
		Vector2(far_point.x, far_point.z)) < 0.01, "Pemain masih dikurung batas pulau")
	player.call("spawn", Vector2.ZERO)
	var weapon: Node3D = visual.get("weapon_instance")
	var attachment: BoneAttachment3D = visual.get("weapon_attachment")
	_check(weapon != null and weapon.visible, "Model pedang tidak tampil pada pemain")
	_check(attachment != null and attachment.bone_name == "hand_r",
		"Model pedang tidak terikat ke tangan kanan")
	_check(str(visual.get("clip")) == "Sword_Idle", "Idle pedang tidak dipakai di Survival")
	var sword_layer: Node = visual.get("sword_layer")
	_check(sword_layer != null and sword_layer.get("tracks").size() > 20,
		"Animasi serang tidak terfilter ke upper-body")
	var zombies: Array = world.get("zombies")
	_check(zombies.size() >= 3, "Gelombang zombie awal tidak muncul")
	var walking := false
	for _frame in range(90):
		await physics_frame
		for zombie in zombies:
			if is_instance_valid(zombie) and str(zombie.visual.get("gait")) == "Zombie_Walk_Fwd_Loop":
				walking = true
		if walking and player.is_on_floor():
			break
	_check(walking, "Zombie tidak memakai klip jalan UAL")
	_check(player.is_on_floor(), "Pemain tidak mendarat di bidang tak berbatas")
	var before_spawn := zombies.size()
	world.set("_spawn_cooldown", 0.0)
	world.call("_process", 0.1)
	zombies = world.get("zombies")
	_check(zombies.size() == before_spawn + 1, "Zombie baru tidak muncul setelah jeda spawn")
	_check(player.call("attack") == "Sword_Regular_A", "Tap pertama bukan tebasan A")
	_check(str(player.call("attack")).is_empty(), "Input kedua otomatis menyambung serangan")
	_check(str(sword_layer.get("current_name")) == "Sword_Regular_A",
		"Layer pedang tidak memutar klip tebasan pertama")
	for expected in ["Sword_Regular_B", "Sword_Regular_C"]:
		var finished := false
		for _frame in range(240):
			await physics_frame
			if not bool(visual.call("_is_sword_attacking")):
				finished = true
				break
		_check(finished, "Ayunan tidak kembali ke locomotion sebelum tap berikutnya")
		_check(str(player.call("attack")) == expected,
			"Variasi tebasan tidak mengikuti input baru: " + expected)
		_check(str(player.call("attack")).is_empty(), "Tap berulang membuat kombo otomatis")
	_check(int(player.get("sword_attack_index")) == 0, "Urutan variasi pedang tidak berputar")
	var death: Node3D = zombies[0]
	death.call("take_damage", 1000)
	_check(bool(death.get("dead")), "Zombie tidak bereaksi pada damage")
	print("[survival-test] zombie=%d serangan=A/B/C gagal=%d" % [
		zombies.size(), _failures])
	game.queue_free()
	await process_frame
	print("[survival-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
