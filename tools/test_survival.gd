extends SceneTree
## Tes mode Survival: tanpa melee, auto-lock sihir, damage, dan hitungan zombie tumbang.

const FirePet = preload("res://src/game/fire_pet.gd")
const Projectile = preload("res://src/game/fire_projectile.gd")

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
	var forest: Node = game.get("_forest")
	_check(forest != null and not str(forest.call("summary")).is_empty(),
		"Model dedaunan tidak menghasilkan MultiMesh")
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
		game.queue_free()
		await process_frame
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
	var attack_button: Button = game.get("_attack")
	var fire_button: Button = game.get("_fire_button")
	var pet: Node = game.get("_pet")
	var weapon: Node3D = visual.get("weapon_instance")
	_check(not bool(player.get("sword_mode")), "Mode Survival masih mengaktifkan pedang")
	_check(weapon == null or not weapon.visible, "Model pedang masih terlihat di Survival")
	_check(str(visual.get("clip")) != "Sword_Idle", "Idle pedang masih dipakai di Survival")
	_check(attack_button != null and not attack_button.visible,
		"HUD Survival masih menawarkan serangan melee")
	_check(fire_button != null and fire_button.visible
		and str(fire_button.get("caption")) == "TEMBAK",
		"Tombol sihir TEMBAK tidak tersedia di Survival")
	game.call("_attack_action")
	_check(not bool(pet.get("casting")) and not bool(visual.call("is_busy")),
		"Input melee masih aktif di mode Survival")
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

	# Susun target uji pada jarak tetap. Sihir harus memilih monster terdekat,
	# mengikuti posisinya, lalu damage kematiannya masuk ke HUD Survival.
	world.set_process(false)
	for index in range(zombies.size()):
		var zombie: Node3D = zombies[index]
		zombie.set_physics_process(false)
		zombie.global_position = Vector3(
			player.global_position.x, 0.9, player.global_position.z + 40.0 + index * 4.0)
	var farther: Node3D = zombies[0]
	var target: Node3D = zombies[1]
	farther.global_position = Vector3(
		player.global_position.x, 0.9, player.global_position.z - 9.0)
	target.global_position = Vector3(
		player.global_position.x, 0.9, player.global_position.z - 6.0)
	var picked: Node3D = world.call("acquire_magic_target", player.global_position)
	_check(picked == target, "Auto-lock tidak memilih zombie hidup yang terdekat")
	var defeated_before := int(world.get("defeated"))
	target.set("health", FirePet.MAGIC_DAMAGE)
	fire_button.pressed.emit()
	_check(bool(pet.get("casting")), "Tombol TEMBAK tidak memulai casting sihir")
	_check(pet.get("_locked_target") == target, "Casting sihir tidak menyimpan target terkunci")
	var saw_homing_projectile := false
	var locked_shot: CharacterBody3D
	for _frame in range(12):
		await physics_frame
		var shots: Array = pet.get("projectiles")
		for shot in shots:
			if is_instance_valid(shot) and shot.get("homing_target") == target:
				saw_homing_projectile = true
				locked_shot = shot
				break
		if saw_homing_projectile:
			break
	_check(saw_homing_projectile, "Proyektil sihir tidak membawa target auto-lock")
	if locked_shot != null:
		_check((int(locked_shot.get("collision_mask")) & 4) != 0,
			"Proyektil tidak mendeteksi layer collision zombie")
		target.global_position += Vector3(1.0, 0.0, 0.0)
		for _frame in range(4):
			await physics_frame
		var to_target := (target.global_position + Projectile.HOMING_AIM_OFFSET
			- locked_shot.global_position).normalized()
		var shot_velocity: Vector3 = locked_shot.get("velocity")
		_check(shot_velocity.normalized().dot(to_target) > 0.96,
			"Proyektil sihir tidak membelok mengikuti target yang bergerak")
	var target_died := false
	for _frame in range(180):
		await physics_frame
		if bool(target.get("dead")):
			target_died = true
			break
	_check(target_died, "Proyektil sihir tidak memberi damage sampai zombie tumbang")
	_check(int(world.get("defeated")) == defeated_before + 1,
		"Kematian zombie tidak menambah hitungan Survival")
	var status: Label = game.get("_survival_status")
	_check(status != null and status.text.contains("KALAH 1"),
		"HUD Survival tidak memperbarui jumlah zombie tumbang")
	_check(world.call("acquire_magic_target", player.global_position) != target,
		"Auto-lock masih memilih zombie yang sudah tumbang")

	print("[survival-test] zombie=%d auto-lock=OK melee=OFF gagal=%d" % [
		zombies.size(), _failures])
	game.queue_free()
	await process_frame
	print("[survival-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
