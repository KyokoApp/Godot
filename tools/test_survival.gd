extends SceneTree
## Tes Survival: top-down, auto-fire, stage satu menit, damage, dan balik ke home.

const FirePet = preload("res://src/game/fire_pet.gd")
const Projectile = preload("res://src/game/fire_projectile.gd")
const SurvivalWorld = preload("res://src/game/world/survival_world.gd")
const Zombie = preload("res://src/game/world/zombie.gd")
const Player = preload("res://src/game/player.gd")
const BuffCatalog = preload("res://src/game/survival/buff_catalog.gd")
const BuffSystem = preload("res://src/game/survival/buff_system.gd")
const MetaProgress = preload("res://src/game/survival/meta_progress.gd")
const TEST_META_SAVE_PATH := "user://survival_run_test_meta.cfg"

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


func _test_repeatable_buff_pool() -> void:
	var catalog_cards := BuffCatalog.all_cards()
	_check(catalog_cards.size() >= 29,
		"Katalog Survival belum memuat banyak pilihan skill buff")
	var catalog_ids: Dictionary = {}
	for card_data: Dictionary in catalog_cards:
		catalog_ids[str(card_data.get("id", ""))] = true
	_check(catalog_ids.size() == catalog_cards.size(),
		"Katalog skill buff memiliki ID kartu duplikat")
	var capped_stacks: Dictionary = {}
	for card_data: Dictionary in catalog_cards:
		var maximum := int(card_data.get("max_stacks", 1))
		if maximum > 0:
			capped_stacks[str(card_data.get("id", ""))] = maximum
	for buff_id in ["ember_core", "long_reach", "ascendant_sigil"]:
		capped_stacks[buff_id] = 999
	var manager := BuffSystem.new()
	manager.set("stacks", capped_stacks)
	var choices: Array = manager.call("available_choices", 3)
	_check(choices.size() == 3,
		"Pool buff akhir run tidak menyediakan tepat tiga pilihan")
	var unique_ids: Dictionary = {}
	for card_data: Dictionary in choices:
		unique_ids[str(card_data.get("id", ""))] = true
	_check(unique_ids.size() == 3,
		"Pool buff akhir run mengulang kartu yang sama")
	for buff_id in ["ember_core", "long_reach", "ascendant_sigil"]:
		_check(bool(manager.call("apply_buff", buff_id)),
			"Buff tanpa batas tidak bisa dipilih lagi: " + buff_id)
	manager.free()
	var skill_manager := BuffSystem.new()
	var new_choices: Array = skill_manager.call("available_choices", catalog_cards.size())
	var new_choice_ids: Dictionary = {}
	for card_data: Dictionary in new_choices:
		new_choice_ids[str(card_data.get("id", ""))] = true
	_check(new_choice_ids.size() == catalog_cards.size(),
		"Tidak semua kartu baru masuk ke pilihan stack Survival")
	for buff_id in ["arcane_focus", "frost_rune", "storm_chain", "vampiric_flame",
			"executioner", "critical_bloom", "soul_ward", "kill_haste", "wildfire",
			"soul_spring", "prismatic_echo", "cinder_pulse", "firestorm_aura",
			"soul_lance", "hunter_brand"]:
		_check(bool(skill_manager.call("apply_buff", buff_id)),
			"Skill kartu baru tidak bisa dipilih: " + buff_id)
	skill_manager.free()


func _run() -> void:
	_remove_test_meta_save()
	_test_repeatable_buff_pool()
	var game := load("res://src/game/legacy_main.tscn").instantiate() as Node3D
	root.add_child(game)
	var test_meta := MetaProgress.new(TEST_META_SAVE_PATH)
	game.set("_meta_progress", test_meta)
	var npc_interaction: Node = game.get("_npc_interaction")
	npc_interaction.set("meta_progress", test_meta)
	var upgrade_menu: Control = npc_interaction.get("_upgrade_menu")
	upgrade_menu.set("meta_progress", test_meta)
	# Bekukan loop main sampai target uji diposisikan, lalu panggil eksplisit
	# untuk membuktikan auto-fire tetap berjalan tanpa event tombol.
	game.set_process(false)
	var forest: Node = game.get("_forest")
	_check(forest != null and not str(forest.call("summary")).is_empty(),
		"Model dedaunan tidak menghasilkan MultiMesh")
	var orbit: Node3D = game.get("_orbit")
	var home_pitch := float(orbit.get("pitch"))
	var home_pitch_min := float(orbit.get("pitch_min"))
	var home_pitch_max := float(orbit.get("pitch_max"))
	var home_distance := float(orbit.get("distance"))
	var home_zoom_enabled := bool(orbit.get("zoom_enabled"))
	for _frame in range(12):
		await physics_frame
	game.call("_enter_survival")
	for _frame in range(8):
		await physics_frame
	var player: CharacterBody3D = game.get("_player")
	var visual: Node3D = game.get("_visual")
	var world: Node3D = game.get("_survival_world")
	var selector: Control = game.get("_mode_selector")
	_check(str(game.get("_active_mode")) == "survival", "Mode Survival tidak aktif")
	_check(world != null, "Dunia Survival tidak dibuat")
	_check(game.get("_scenery") == null and world.get_node_or_null("CityHorizon") == null,
		"Skyline/bukit home ikut dimuat ke gameplay Survival")
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
	var pet: Node3D = game.get("_pet")
	var weapon: Node3D = visual.get("weapon_instance")
	_check(not bool(player.get("sword_mode")), "Mode Survival masih mengaktifkan pedang")
	_check(weapon == null or not weapon.visible, "Model pedang masih terlihat di Survival")
	_check(str(visual.get("clip")) != "Sword_Idle", "Idle pedang masih dipakai di Survival")
	_check(attack_button != null and not attack_button.is_visible_in_tree()
		and attack_button.disabled,
		"HUD Survival masih menawarkan serangan melee")
	_check(fire_button != null and not fire_button.is_visible_in_tree()
		and fire_button.disabled,
		"Tombol aksi TEMBAK masih terlihat/aktif di Survival")
	_check(float(orbit.get("pitch")) >= 1.25
		and float(orbit.get("pitch")) <= 1.30,
		"Kamera Survival tidak top-down dengan kemiringan ringan")
	_check(float(orbit.get("pitch_min")) >= 1.15,
		"Kamera Survival bisa ditarik keluar dari sudut top-down")
	var initial_stage_time := float(world.get("stage_time_left"))
	_check(initial_stage_time <= SurvivalWorld.STAGE_DURATION
		and initial_stage_time > SurvivalWorld.STAGE_DURATION - 2.0,
		"Stage pertama tidak dimulai dengan timer satu menit")
	_check(int(world.get("stage")) == 1, "Stage awal bukan stage 1")
	_check(int(world.get("run_level")) == 1 and int(world.get("experience")) == 0,
		"Progress level Survival tidak mulai dari nol")
	var survival_hud: Control = game.get("_survival_hud")
	_check(survival_hud != null and survival_hud.get_node_or_null("SurvivalProfile") != null,
		"HUD profil Survival tidak dibuat")
	_check(survival_hud != null
		and survival_hud.get_node_or_null("BuffChoiceBackdrop") != null,
		"Overlay kartu buff tidak dibuat")
	_check(survival_hud != null
		and survival_hud.get_node_or_null("BossHealthPanel") != null
		and survival_hud.get_node_or_null("TowerPrompt") != null,
		"HUD boss/tower tidak dibuat")
	var buffs: Node = world.get("buff_system")
	_check(buffs != null, "Manager buff run tidak dibuat")
	_check(float(orbit.get("distance")) == 17.0,
		"Jarak kamera Survival tidak mengikuti framing top-down")
	_check(not bool(orbit.get("zoom_enabled")),
		"Zoom kamera top-down masih aktif")
	var survival_distance := float(orbit.get("distance"))
	orbit.call("zoom_by", 2.0)
	var wheel_zoom := InputEventMouseButton.new()
	wheel_zoom.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_zoom.pressed = true
	orbit.call("_input", wheel_zoom)
	_check(is_equal_approx(float(orbit.get("distance")), survival_distance),
		"Kamera Survival masih bisa di-zoom lewat API/roda tetikus")
	_check(is_equal_approx(float(fire_button.get("auto_repeat_interval")), 0.0),
		"Auto-fire masih bergantung pada menahan tombol TEMBAK")
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
	game.call("_process", FirePet.AUTO_FIRE_INTERVAL)
	_check(bool(pet.get("casting")), "Sihir tidak otomatis mulai casting tanpa input")
	_check(pet.get("_locked_target") == target,
		"Auto-fire tidak mengunci zombie hidup yang terdekat")
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
	_check(int(world.get("experience")) == 24 and int(world.get("run_level")) == 1,
		"Kill zombie tidak memberi EXP run-only")
	var status: Label = game.get("_survival_status")
	_check(status != null and status.text.contains("KALAH 1"),
		"HUD Survival tidak memperbarui jumlah zombie tumbang")
	_check(world.call("acquire_magic_target", player.global_position) != target,
		"Auto-lock masih memilih zombie yang sudah tumbang")

	# Auto-fire mandiri: jangan kirim tap/hold; cukup jalankan loop main.
	farther.set("health", 10000)
	var shots_before := int(pet.get("shots_fired"))
	for _frame in range(180):
		game.call("_process", 1.0 / 60.0)
		await physics_frame
		if int(pet.get("shots_fired")) >= shots_before + 3:
			break
	var shots_after := int(pet.get("shots_fired"))
	_check(shots_after >= shots_before + 3,
		"Tanpa input tombol, Survival tidak menembak zombie berulang kali")
	var cast_layer: Node = visual.get("cast_layer")
	_check(bool(cast_layer.get("holding_pose")),
		"Tangan sihir tidak tetap terangkat saat auto-fire Survival berlanjut")
	for _frame in range(90):
		game.call("_process", 1.0 / 60.0)
		await physics_frame
		if int(farther.get("health")) <= 10000 - FirePet.MAGIC_DAMAGE * 2:
			break
	_check(int(farther.get("health")) <= 10000 - FirePet.MAGIC_DAMAGE * 2,
		"Auto-fire tanpa input tidak memberi hit beruntun ke zombie")
	farther.global_position = player.global_position + Vector3(0, 0, 80)
	for _frame in range(60):
		game.call("_process", 1.0 / 60.0)
		await physics_frame
	_check(not bool(cast_layer.get("holding_pose")) and not bool(cast_layer.get("active")),
		"Pose tangan tidak turun setelah Survival berhenti menembak")

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
	_check(int(world.call("maximum_living_zombies")) > SurvivalWorld.BASE_MAX_LIVING
		and float(world.call("spawn_interval_for_stage")) < SurvivalWorld.SPAWN_INTERVAL,
		"Kapasitas/tempo spawn tidak meningkat mengikuti stage")
	var stage_two_health := 0
	for zombie in world.get("zombies"):
		if is_instance_valid(zombie) and int(zombie.get("stage")) == 2:
			stage_two_health = int(zombie.get("max_health"))
			break
	_check(stage_two_health == Zombie.START_HEALTH + Zombie.STAGE_HEALTH_GAIN,
		"HP zombie stage 2 tidak lebih tebal")
	_check(status != null and status.text.contains("STAGE 02")
		and status.text.contains("01:00"), "HUD tidak menampilkan stage/timer baru")
	zombies = world.get("zombies")
	for zombie in zombies:
		if is_instance_valid(zombie):
			zombie.set_physics_process(false)

	# Level lima membuka tiga kartu, memberi satu pilihan, lalu mengubah statistik/VFX run.
	var stage_two_base_reward := SurvivalWorld.BASE_KILL_EXPERIENCE + 2
	var stage_two_reward := roundi(stage_two_base_reward * float(buffs.get("xp_multiplier")))
	var coins_before_kill := int(game.get("_meta_progress").get("coins"))
	world.set("run_level", 4)
	world.set("experience", int(world.call("_experience_required", 4)) - stage_two_reward)
	var xp_test_zombie: Node3D
	for zombie in zombies:
		if is_instance_valid(zombie) and bool(zombie.call("can_be_targeted")):
			xp_test_zombie = zombie
			break
	world.call("_on_zombie_died", xp_test_zombie)
	_check(int(game.get("_meta_progress").get("coins")) > coins_before_kill,
		"Kill zombie tidak memberi koin persisten")
	_check(bool(survival_hud.get("kill_label").text.contains("KOIN")),
		"HUD Survival tidak menampilkan saldo koin")
	_check(int(world.get("run_level")) == 5,
		"EXP tidak menaikkan level sampai level 5")
	_check(bool(world.get("_awaiting_buff_choice")) and paused,
		"Level kelipatan 5 tidak membuka pilihan buff dan pause gameplay")
	var choice_row := survival_hud.get_node(
		"BuffChoiceBackdrop/BuffChoicePanel/Margin/Content/CardRow")
	_check(choice_row.get_child_count() == 3,
		"Level 5 tidak menampilkan tepat tiga kartu buff")
	if choice_row.get_child_count() == 3:
		var chosen_buff_id := ""
		for choice in choice_row.get_children():
			var option_id := str(choice.get("buff_id"))
			if option_id != "arcane_aegis":
				chosen_buff_id = option_id
				break
		if chosen_buff_id.is_empty():
			chosen_buff_id = str(choice_row.get_child(0).get("buff_id"))
		survival_hud.call("_on_buff_card_pressed", chosen_buff_id)
		for _frame in range(36):
			await process_frame
			if not paused:
				break
		_check(not paused and int(buffs.call("get_stacks", chosen_buff_id)) == 1,
			"Memilih kartu tidak menerapkan tepat satu buff")
	if paused:
		paused = false
	_check(bool(buffs.call("apply_buff", "cinder_orbit")),
		"Buff api orbit tidak dapat diambil")
	var orbit_nodes: Array = buffs.get("_orbit_nodes")
	_check(orbit_nodes.size() == 2,
		"Stack pertama orbit bara harus memunculkan dua api orbit")
	if orbit_nodes.size() == 2:
		var orbit_radius := Vector2(orbit_nodes[0].position.x, orbit_nodes[0].position.z).length()
		_check(orbit_radius >= 1.45,
			"Api orbit terlalu rapat ke pemain: %.2f m" % orbit_radius)
	_check(bool(buffs.call("apply_buff", "cinder_orbit")),
		"Stack kedua Orbit Bara gagal")
	var two_stack_orbit: Array = buffs.get("_orbit_nodes")
	_check(two_stack_orbit.size() == 3,
		"Stack kedua Orbit Bara tidak menambah api orbit")
	_check(bool(buffs.call("apply_buff", "cinder_orbit")),
		"Stack ketiga Orbit Bara gagal")
	var three_stack_orbit: Array = buffs.get("_orbit_nodes")
	_check(three_stack_orbit.size() == 4,
		"Stack ketiga Orbit Bara tidak menambah api orbit")
	_check(not bool(buffs.call("apply_buff", "cinder_orbit")),
		"Orbit Bara melewati batas stack")
	_check(bool(buffs.call("apply_buff", "arcane_aegis")),
		"Buff shield arcana tidak dapat diambil")
	var aegis_mesh: MeshInstance3D = buffs.get("_aegis_mesh")
	_check(int(player.get("shield_capacity")) >= 70
		and int(player.get("shield_points")) >= 70
		and is_instance_valid(aegis_mesh) and aegis_mesh.visible,
		"Buff shield tidak memberi barier visual dan kapasitas shield")
	var hp_before_shield := int(player.get("health"))
	var shield_before_hit := int(player.get("shield_points"))
	player.call("take_damage", 24)
	_check(int(player.get("health")) == hp_before_shield
		and int(player.get("shield_points")) < shield_before_hit,
		"Shield tidak menyerap damage sebelum HP")
	var base_damage_multiplier := float(pet.get("damage_multiplier"))
	_check(bool(buffs.call("apply_buff", "arcane_focus")),
		"Buff fokus arkana tidak dapat diambil")
	_check(float(pet.get("damage_multiplier")) > base_damage_multiplier,
		"Fokus arkana tidak menaikkan damage sihir")
	var base_echo_chance := float(pet.get("extra_shot_chance"))
	_check(bool(buffs.call("apply_buff", "prismatic_echo")),
		"Buff echo prismatik tidak dapat diambil")
	_check(float(pet.get("extra_shot_chance")) > base_echo_chance,
		"Echo prismatik tidak menaikkan peluang tembakan ganda")
	_check(bool(buffs.call("apply_buff", "soul_lance")),
		"Skill single-target Tombak Jiwa tidak dapat dipilih")
	_check(float(pet.get("single_target_multiplier")) >= 1.08,
		"Tombak Jiwa tidak memperkuat proyektil terkunci")
	_check(bool(buffs.call("apply_buff", "hunter_brand")),
		"Skill tanda single-target tidak dapat dipilih")
	var capacity_before_ward := int(player.get("shield_capacity"))
	_check(bool(buffs.call("apply_buff", "soul_ward")),
		"Buff perisai jiwa tidak dapat diambil")
	_check(int(player.get("shield_capacity")) >= capacity_before_ward + 20,
		"Perisai jiwa tidak menambah kapasitas shield")
	_check(bool(buffs.call("apply_buff", "burning_brand")),
		"Buff sihir pembakar tidak dapat diambil")
	_check(bool(buffs.call("apply_buff", "wildfire")),
		"Buff kebakaran liar tidak dapat diambil")
	_check(bool(buffs.call("apply_buff", "frost_rune")),
		"Buff runa embun tidak dapat diambil")
	_check(bool(buffs.call("apply_buff", "storm_chain")),
		"Buff rantai petir tidak dapat diambil")
	_check(bool(buffs.call("apply_buff", "vampiric_flame")),
		"Buff api penghisap tidak dapat diambil")
	_check(bool(buffs.call("apply_buff", "executioner")),
		"Buff tanda penuai tidak dapat diambil")
	_check(bool(buffs.call("apply_buff", "kill_haste")),
		"Buff ritme penuai tidak dapat diambil")
	_check(bool(buffs.call("apply_buff", "soul_spring")),
		"Buff mata air jiwa tidak dapat diambil")
	var live_burn_target: Node3D
	for zombie in zombies:
		if is_instance_valid(zombie) and zombie.call("can_be_targeted"):
			live_burn_target = zombie
			break
	var chain_target: Node3D
	var chain_health_before := 0
	if live_burn_target != null:
		for zombie in zombies:
			if is_instance_valid(zombie) and zombie != live_burn_target \
					and zombie.call("can_be_targeted"):
				chain_target = zombie
				break
	if live_burn_target != null:
		if chain_target != null:
			chain_target.global_position = live_burn_target.global_position + Vector3(2.0, 0, 0)
			chain_health_before = int(chain_target.get("health"))
		var health_before_impact := int(player.get("health"))
		pet.emit_signal("impact_landed", live_burn_target, FirePet.MAGIC_DAMAGE, false)
		_check(float(live_burn_target.get("_burn_left")) > 0.0
			and int(live_burn_target.get("_burn_damage")) >= 7,
			"Burning Brand/Wildfire tidak menerapkan damage bakar")
		_check(float(live_burn_target.get("_slow_left")) > 0.0
			and float(live_burn_target.get("_slow_multiplier")) < 1.0,
			"Runa embun tidak memperlambat zombie")
		_check(float(live_burn_target.get("_arcane_mark_left")) > 0.0
			and float(live_burn_target.get("_arcane_mark_bonus")) > 0.0,
			"Cap Pemburu tidak menandai target tunggal")
		if chain_target != null:
			_check(int(chain_target.get("health")) < chain_health_before,
				"Rantai petir tidak memberi damage ke zombie lain")
		player.set("health", maxi(1, health_before_impact - 20))
		var health_after_setup := int(player.get("health"))
		pet.emit_signal("impact_landed", live_burn_target, FirePet.MAGIC_DAMAGE, false)
		_check(int(player.get("health")) > health_after_setup,
			"Api penghisap tidak memulihkan HP dari damage sihir")
		if chain_target != null:
			var maximum_health := int(chain_target.get("max_health"))
			chain_target.set("health", maxi(1, roundi(maximum_health * 0.30)))
			var execution_health_before := int(chain_target.get("health"))
			buffs.call("_on_magic_impact", chain_target, FirePet.MAGIC_DAMAGE, false)
			_check(int(chain_target.get("health")) < execution_health_before,
				"Tanda penuai tidak memberi bonus damage saat zombie sekarat")
		var bloom_target: Node3D
		for zombie in zombies:
			if is_instance_valid(zombie) and zombie != live_burn_target \
					and zombie != chain_target and zombie.call("can_be_targeted"):
				bloom_target = zombie
				break
		if bloom_target != null:
			bloom_target.global_position = live_burn_target.global_position + Vector3(2.0, 0, 0)
			bloom_target.set("health", int(bloom_target.get("max_health")))
			var bloom_health_before := int(bloom_target.get("health"))
			var bloom_manager := BuffSystem.new()
			bloom_manager.world = world
			bloom_manager.stacks = {"critical_bloom": 1}
			bloom_manager.call("_on_magic_impact", live_burn_target,
				FirePet.MAGIC_DAMAGE, true)
			_check(int(bloom_target.get("health")) < bloom_health_before,
				"Bunga kritikal tidak memberi damage area saat critical")
			bloom_manager.free()
		var health_maximum := int(player.get("max_health"))
		player.set("health", maxi(1, health_maximum - 8))
		var health_before_regen := int(player.get("health"))
		buffs.call("_process", 1.1)
		_check(int(player.get("health")) > health_before_regen,
			"Mata air jiwa tidak memulihkan HP seiring waktu")
		player.set("shield_points", 0)
		pet.set("cooldown", 0.8)
		var cooldown_before_kill := float(pet.get("cooldown"))
		buffs.call("on_zombie_killed", live_burn_target)
		_check(int(player.get("shield_points")) >= 5 * int(buffs.call("get_stacks", "soul_ward")),
			"Kill tidak mengisi shield Perisai Jiwa")
		_check(float(pet.get("cooldown")) < cooldown_before_kill,
			"Kill tidak memangkas cooldown dengan Ritme Penuai")
	var skill_target: Node3D
	for zombie in zombies:
		if is_instance_valid(zombie) and zombie.can_be_targeted():
			skill_target = zombie
			break
	if skill_target != null:
		var pulse_probe := BuffSystem.new()
		pulse_probe.player = player
		pulse_probe.world = world
		pulse_probe.stacks = {"cinder_pulse": 1}
		for _hit in 5:
			pulse_probe.call("_on_magic_impact", skill_target, FirePet.MAGIC_DAMAGE, false)
		var pulse_waves: Array = pulse_probe.get("_skill_waves")
		_check(pulse_waves.size() == 1,
			"Denyut Bara tidak memicu gelombang AoE berkala")
		pulse_probe.free()
	var storm_probe := BuffSystem.new()
	storm_probe.player = player
	storm_probe.world = world
	storm_probe.stacks = {"firestorm_aura": 1}
	storm_probe.call("_process", 5.3)
	var storm_waves: Array = storm_probe.get("_skill_waves")
	_check(storm_waves.size() == 1,
		"Badai Api tidak memicu gelombang AoE otomatis")
	storm_probe.free()
	for _frame in range(50):
		await physics_frame
	_check(int(world.get("experience")) >= 0
		and int(world.get("run_level")) == 5,
		"Level/EXP berubah tidak semestinya setelah memilih buff")

	# Boss muncul di awal stage kelipatan lima; tower baru hadir setelah timer stage selesai.
	world.set("run_level", 1)
	world.set("experience", 0)
	world.set("stage", 4)
	world.set("_stage_elapsed", SurvivalWorld.STAGE_DURATION - 0.2)
	world.set("_spawn_cooldown", 100.0)
	world.call("_process", 0.3)
	_check(int(world.get("stage")) == 5, "Stage 5 tidak dimulai")
	var boss: Node3D = world.get("boss")
	_check(boss != null and bool(boss.get("is_boss")),
		"Boss raksasa tidak muncul pada stage 5")
	if boss != null:
		_check(float(boss.get("max_health")) >= 900.0
			and str(boss.get("boss_name")) == "GOLIAT ABU",
			"Boss stage 5 tidak punya nama/HP khusus")
		var boss_visual: Node3D = boss.get("visual")
		_check(boss_visual != null and float(boss_visual.scale.x) >= 1.6,
			"Model boss tidak terlihat raksasa")
		var character_skin: Object = boss_visual.get("skin")
		var boss_skin := character_skin.get("skin") as ShaderMaterial
		var boss_light: Color = boss_skin.get_shader_parameter("skin_light")
		_check(boss_light.b > boss_light.r,
			"Skin boss stage 5 tidak berbeda dari zombie biasa")
	var later_boss := Zombie.new()
	later_boss.call("set_stage_difficulty", 10, true)
	var stage_five_name := str(boss.get("boss_name")) if boss != null else ""
	_check(str(later_boss.get("boss_name")) != stage_five_name,
		"Boss stage 10 tidak mendapat identitas skin berbeda")
	later_boss.free()
	_check(survival_hud.boss_panel.visible,
		"Bar HP boss tidak tampil saat boss muncul")
	world.set("_stage_elapsed", SurvivalWorld.STAGE_DURATION - 0.1)
	world.call("_process", 0.2)
	var tower: Node3D = world.get("tower")
	_check(tower != null and bool(world.get("_tower_active"))
		and int(world.get("stage")) == 5,
		"Tower pilihan tidak muncul setelah stage 5 selesai")
	if tower != null:
		player.global_position += Vector3(24.0, 0.0, 0.0)
		world.call("_process", 0.1)
		_check(not bool(world.get("_awaiting_tower_choice")),
			"Pilihan tower muncul sebelum pemain mendekat")
		player.global_position = tower.global_position + Vector3(0.0, Player.HEIGHT * 0.5, 2.0)
		world.call("_process", 0.1)
		_check(bool(world.get("_awaiting_tower_choice")) and paused,
			"Masuk area tower tidak membuka pilihan lanjut/keluar")
		_check(int(world.call("living_zombie_count")) == 0,
			"Gelombang tower tidak membersihkan semua zombie")
		_check(survival_hud.get_node("TowerChoiceBackdrop").visible,
			"Dialog pilihan tower tidak tampil")
		survival_hud.call("_finish_tower_choice", "continue")
		_check(not paused and int(world.get("stage")) == 6,
			"Pilihan lanjut tidak memulai stage berikutnya")
	_check(int(game.get("_meta_progress").get("coins")) > coins_before_kill,
		"Hadiah koin tower/boss tidak tersimpan")

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
	_check(not survival_hud.get_node("BossHealthPanel").visible
		and not survival_hud.get_node("TowerPrompt").visible,
		"Panel boss/prompt tower tertinggal setelah kembali ke home")
	_check(int(player.get("health")) == 100, "HP tidak pulih setelah kembali ke home")
	_check(is_equal_approx(float(orbit.get("pitch")), home_pitch),
		"Kamera tidak kembali ke sudut home")
	_check(is_equal_approx(float(orbit.get("pitch_min")), home_pitch_min)
		and is_equal_approx(float(orbit.get("pitch_max")), home_pitch_max)
		and is_equal_approx(float(orbit.get("distance")), home_distance)
		and bool(orbit.get("zoom_enabled")) == home_zoom_enabled,
		"Batas/jarak kamera home berubah setelah Survival")
	_check(is_equal_approx(float(fire_button.get("auto_repeat_interval")), 0.0),
		"Auto-fire tidak berhenti setelah keluar dari Survival")
	var hub_shots_before := int(pet.get("shots_fired"))
	game.call("_process", FirePet.AUTO_FIRE_INTERVAL * 2.0)
	_check(int(pet.get("shots_fired")) == hub_shots_before,
		"Auto-fire Survival masih menembak setelah kembali ke hub")
	_check(is_equal_approx(float(pet.get("cooldown_duration")), FirePet.COOLDOWN)
		and int(pet.get("projectile_limit")) == FirePet.MAX_PROJECTILES,
		"Setelan tembak hub tidak dipulihkan setelah Survival")
	game.call("_enter_survival")
	var fresh_world: Node = game.get("_survival_world")
	var fresh_buffs: Node = fresh_world.get("buff_system")
	var fresh_stacks: Dictionary = fresh_buffs.get("stacks")
	_check(int(fresh_world.get("run_level")) == 1
		and int(fresh_world.get("experience")) == 0,
		"Level/EXP tersimpan antar-run Survival")
	_check(fresh_stacks.is_empty()
		and int(player.get("max_health")) == Player.MAX_HEALTH
		and int(player.get("shield_points")) == 0,
		"Buff/bonus HP tersimpan saat mulai run baru")
	_check(not bool(orbit.get("zoom_enabled")) and is_equal_approx(float(orbit.get("distance")), 17.0),
		"Kamera top-down tidak terkunci permanen pada run baru")
	fresh_world.set("_awaiting_tower_choice", true)
	fresh_world.call("choose_tower_action", "exit")
	_check(str(game.get("_active_mode")) == "hub"
		and game.get("_survival_world") == null,
		"Pilihan keluar di tower tidak kembali ke home")
	print("[survival-test] top-down=OK autofire=%d stage=2 level=5 reset-run=%s gagal=%d" % [
		shots_after - shots_before, str(returned_home), _failures])
	game.queue_free()
	await process_frame
	_remove_test_meta_save()
	print("[survival-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)


func _remove_test_meta_save() -> void:
	var path := ProjectSettings.globalize_path(TEST_META_SAVE_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
