extends SceneTree
## Tes Survival: top-down, auto-fire, stage satu menit, damage, dan balik ke home.

const FirePet = preload("res://src/game/fire_pet.gd")
const Projectile = preload("res://src/game/fire_projectile.gd")
const SurvivalWorld = preload("res://src/game/world/survival_world.gd")

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


func _touch(index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	root.push_input(event, true)


func _run() -> void:
	var game := load("res://src/game/main.tscn").instantiate() as Node3D
	root.add_child(game)
	var forest: Node = game.get("_forest")
	_check(forest != null and not str(forest.call("summary")).is_empty(),
		"Model dedaunan tidak menghasilkan MultiMesh")
	var orbit: Node3D = game.get("_orbit")
	var home_pitch := float(orbit.get("pitch"))
	var home_pitch_min := float(orbit.get("pitch_min"))
	var home_pitch_max := float(orbit.get("pitch_max"))
	var home_distance := float(orbit.get("distance"))
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
	_check(float(orbit.get("pitch")) >= 1.28
		and float(orbit.get("pitch")) <= 1.50,
		"Kamera Survival tidak berada di sudut top-down")
	_check(float(orbit.get("pitch_min")) >= 1.2,
		"Kamera Survival bisa ditarik keluar dari sudut top-down")
	var initial_stage_time := float(world.get("stage_time_left"))
	_check(initial_stage_time <= SurvivalWorld.STAGE_DURATION
		and initial_stage_time > SurvivalWorld.STAGE_DURATION - 2.0,
		"Stage pertama tidak dimulai dengan timer satu menit")
	_check(int(world.get("stage")) == 1, "Stage awal bukan stage 1")
	_check(float(orbit.get("distance")) == 17.0,
		"Jarak kamera Survival tidak mengikuti framing top-down")
	_check(float(fire_button.get("auto_repeat_interval")) > 0.0,
		"Tombol sihir tidak mengaktifkan auto-fire saat ditahan")
	_check(is_equal_approx(float(pet.get("cooldown_duration")), FirePet.RAPID_FIRE_COOLDOWN),
		"Cooldown sihir tidak dipercepat di Survival")
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

	# Target terdekat diam dulu supaya auto-lock dan hit bisa diuji deterministik.
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

	# Tahan tombol: satu tekan awal diikuti beberapa tembakan beruntun.
	farther.set("health", 10000)
	var shots_before := int(pet.get("shots_fired"))
	var fire_point := fire_button.get_global_rect().get_center()
	_touch(21, fire_point, true)
	for _frame in range(90):
		await physics_frame
		if int(pet.get("shots_fired")) >= shots_before + 4:
			break
	_touch(21, fire_point, false)
	var shots_after := int(pet.get("shots_fired"))
	_check(shots_after >= shots_before + 3,
		"Tahan tombol TEMBAK tidak mengeluarkan burst otomatis")
	for _frame in range(40):
		await physics_frame
		if int(farther.get("health")) <= 10000 - FirePet.MAGIC_DAMAGE * 2:
			break
	_check(int(farther.get("health")) <= 10000 - FirePet.MAGIC_DAMAGE * 2,
		"Auto-fire tidak memberi hit beruntun ke zombie")

	# Lewati satu menit secara deterministik: stage naik, timer reset, dan wave membesar.
	var wave_one_size := int(world.get("last_spawn_wave_size"))
	var living_before_stage := int(world.call("living_zombie_count"))
	var stage_remaining := SurvivalWorld.STAGE_DURATION - float(world.get("_stage_elapsed"))
	world.call("_process", stage_remaining)
	_check(int(world.get("stage")) == 2, "Stage tidak naik setelah satu menit")
	_check(is_equal_approx(float(world.get("stage_time_left")), SurvivalWorld.STAGE_DURATION),
		"Timer stage baru tidak kembali ke satu menit")
	_check(int(world.get("last_spawn_wave_size")) > wave_one_size,
		"Wave stage 2 tidak menambah jumlah zombie yang muncul")
	_check(int(world.call("living_zombie_count")) > living_before_stage,
		"Stage baru tidak menambah jumlah zombie hidup")
	_check(status != null and status.text.contains("STAGE 02")
		and status.text.contains("01:00"), "HUD tidak menampilkan stage/timer baru")
	zombies = world.get("zombies")
	for zombie in zombies:
		if is_instance_valid(zombie):
			zombie.set_physics_process(false)

	# Mati di Survival harus membangun kembali hub, bukan meninggalkan arena kosong.
	player.call("take_damage", 1000)
	var returned_home := false
	for _frame in range(120):
		await physics_frame
		if str(game.get("_active_mode")) == "hub":
			returned_home = true
			break
	_check(returned_home, "Pemain mati tetapi tidak kembali ke home")
	_check(game.get("_survival_world") == null, "Dunia Survival masih aktif setelah kembali")
	_check(game.get("_field") != null and game.get("_npc") != null,
		"Hub tidak dibangun kembali setelah mati")
	var survival_panel: Control = game.get("_survival_panel")
	_check(survival_panel != null and not survival_panel.visible,
		"Panel Survival masih tampil di home")
	_check(int(player.get("health")) == 100, "HP tidak pulih setelah kembali ke home")
	_check(is_equal_approx(float(orbit.get("pitch")), home_pitch),
		"Kamera tidak kembali ke sudut home")
	_check(is_equal_approx(float(orbit.get("pitch_min")), home_pitch_min)
		and is_equal_approx(float(orbit.get("pitch_max")), home_pitch_max)
		and is_equal_approx(float(orbit.get("distance")), home_distance),
		"Batas/jarak kamera home berubah setelah Survival")
	_check(is_equal_approx(float(fire_button.get("auto_repeat_interval")), 0.0),
		"Auto-fire tidak berhenti setelah keluar dari Survival")
	_check(is_equal_approx(float(pet.get("cooldown_duration")), FirePet.COOLDOWN)
		and int(pet.get("projectile_limit")) == FirePet.MAX_PROJECTILES,
		"Setelan tembak hub tidak dipulihkan setelah Survival")
	print("[survival-test] top-down=OK autofire=%d stage=2 return-home=%s gagal=%d" % [
		shots_after - shots_before, str(returned_home), _failures])
	game.queue_free()
	await process_frame
	print("[survival-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
