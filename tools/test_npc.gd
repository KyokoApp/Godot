extends SceneTree
## Uji NPC: idle berbeda, jalan sesekali, interaksi dekat, transisi UI, dan pulih.

const Field = preload("res://src/game/world/field.gd")
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
	for _frame in range(12):
		await physics_frame
	var field: Node = game.get("_field")
	var player: CharacterBody3D = game.get("_player")
	var npc: Node3D = game.get("_npc")
	var player_visual: Node3D = game.get("_visual")
	var npc_visual: Node3D = npc.get("visual") if npc != null else null
	_check(
		field != null and is_equal_approx(Field.SIZE, 100.0),
		"Dunia interaksi tidak berukuran 100 m"
	)
	_check(npc != null and npc.get("display_name") == "Mira", "NPC Mira tidak dibuat")
	_check(npc_visual != null, "Visual NPC tidak ditemukan")
	if npc_visual != null and player_visual != null:
		_check(
			str(npc_visual.get("clip")) == "Idle_FoldArms_Loop",
			"Idle NPC tidak berbeda: %s" % str(npc_visual.get("clip"))
		)
		_check(
			str(npc_visual.get("clip")) != str(player_visual.get("clip")),
			"Idle NPC sama dengan idle pemain"
		)

	# Paksa timer idle lewat jalur pemilih yang dipakai runtime; seed NPC tetap,
	# jadi tes tidak perlu menunggu beberapa siklus acak.
	if npc != null:
		for _attempt in range(40):
			if int(npc.get("walk_count")) > 0:
				break
			npc.set("_idle_time", 0.0)
			npc.call("_physics_process", 1.0 / 60.0)
		_check(int(npc.get("walk_count")) > 0, "NPC tidak pernah memilih untuk berjalan")
		_check(bool(npc.get("_walking")), "NPC tidak menyiapkan gerak wander")
		for _frame in range(120):
			if bool(npc.call("is_walking")):
				break
			await physics_frame
		_check(bool(npc.call("is_walking")), "NPC tidak menghadap jalur sebelum berjalan")
		if npc_visual != null:
			_check(
				str(npc_visual.get("clip")) == "Walk_Loop",
				"NPC memakai klip jalan depan yang salah: %s" % str(npc_visual.get("clip"))
			)
			var target: Vector2 = npc.get("_walk_target")
			var direction := target - Vector2(npc.global_position.x, npc.global_position.z)
			var facing := atan2(-direction.x, -direction.y)
			var error := absf(wrapf(facing - npc_visual.rotation.y, -PI, PI))
			_check(
				error < 0.04, "NPC mulai berjalan menyamping: sudut arah %.2f°" % rad_to_deg(error)
			)
		var before := npc.global_position
		for _frame in range(24):
			await physics_frame
		_check(
			(
				Vector2(npc.global_position.x - before.x, npc.global_position.z - before.z).length()
				> 0.15
			),
			"NPC tidak berpindah saat berjalan"
		)

	var interaction: Node = game.get("_npc_interaction")
	var joystick: Control = game.get("_joystick")
	var orbit: Node = game.get("_orbit")
	if interaction == null or npc == null or player == null:
		_check(false, "Jalur interaksi belum disiapkan")
	else:
		player.spawn(Vector2(npc.global_position.x, npc.global_position.z + 1.5))
		for _frame in range(2):
			await process_frame
		var prompt: Control = interaction.get("_prompt")
		var original_yaw := float(orbit.get("yaw"))
		var original_distance := float(orbit.get("distance"))
		var original_focus: Vector3 = orbit.get("focus_offset")
		_check(prompt != null and prompt.visible, "Tombol bicara tidak muncul saat dekat NPC")
		interaction.call("_begin_interaction")
		var dialogue: Control = interaction.get("_dialogue")
		await create_timer(0.7).timeout
		_check(bool(interaction.call("is_open")), "Interaksi tidak membuka layar pilihan")
		_check(dialogue != null and dialogue.visible, "Layar dialog tidak terlihat")
		if dialogue != null:
			var options: Array = dialogue.get("_options")
			_check(options.size() == 4, "Pilihan gameplay tidak lengkap: %d" % options.size())
			var option_labels: Array = dialogue.get("_option_labels")
			_check(option_labels[0].text.contains("GAMEPLAY"),
				"Opsi pertama dialog NPC bukan Gameplay")
			var page: Control = dialogue.get("_page")
			var backdrop: ColorRect = dialogue.get("_backdrop")
			_check(
				page != null
				and is_zero_approx(page.offset_left)
				and is_zero_approx(page.offset_top)
				and is_zero_approx(page.offset_right)
				and is_zero_approx(page.offset_bottom),
				"Menu tidak memenuhi layar tanpa margin luar"
			)
			_check(
				backdrop != null and backdrop.color.a < 0.5,
				"Dunia game tertutup oleh lapisan latar opak"
			)
			_check(dialogue.get("_sidebar") != null, "Panel menu miring tidak dibuat")
			_check(
				float(orbit.get("distance")) < original_distance - 0.2,
				"Kamera tidak zoom ke karakter saat menu dibuka"
			)
			var yaw_change := absf(wrapf(float(orbit.get("yaw")) - original_yaw, -PI, PI))
			_check(yaw_change > 0.3, "Kamera tidak membingkai karakter di sisi kanan")
			var conversation_focus: Vector3 = orbit.get("focus_offset")
			_check(
				conversation_focus.distance_to(original_focus) > 0.1,
				"Titik pandang kamera tidak bergeser ke percakapan"
			)
			dialogue.call("move_selection", 1)
			_check(int(dialogue.get("_selected")) == 1, "Navigasi pilihan tidak berpindah")
			_check(option_labels[1].text.contains("UPGRADE ATRIBUT"),
				"Opsi INVENTARIS tidak diganti menjadi upgrade atribut")
			dialogue.call("activate_selected")
			var notice: Label = dialogue.get("_notice")
			var upgrade_menu: Control = interaction.get("_upgrade_menu")
			var upgrade_grid: GridContainer = upgrade_menu.get("_grid") if upgrade_menu != null else null
			_check(upgrade_menu != null and upgrade_menu.visible,
				"Opsi upgrade atribut tidak membuka panel peningkatan")
			_check(upgrade_grid != null and upgrade_grid.get_child_count() >= 12,
				"Upgrade atribut belum menyediakan banyak pilihan")
			_check(notice != null and not notice.text.contains("COMING SOON"),
				"Upgrade atribut salah ditandai Coming Soon")
			if upgrade_menu != null:
				upgrade_menu.call("close")
				await create_timer(0.35).timeout
				dialogue.call("move_selection", 1)
				dialogue.call("activate_selected")
				_check(notice != null and notice.text.contains("COMING SOON"),
					"Status karakter yang belum tersedia harus tetap Coming Soon")
		_check(not bool(joystick.get("input_enabled")), "Joystick aktif saat dialog terbuka")
		_check(not bool(orbit.get("input_enabled")), "Kamera aktif saat dialog terbuka")
		dialogue.call("close_dialogue")
		await create_timer(0.8).timeout
		_check(not bool(interaction.call("is_open")), "Dialog tidak menutup dengan transisi")
		_check(bool(joystick.get("input_enabled")), "Joystick tidak pulih setelah dialog")
		_check(bool(orbit.get("input_enabled")), "Kamera tidak pulih setelah dialog")
		_check(
			absf(float(orbit.get("distance")) - original_distance) < 0.03,
			"Jarak kamera tidak pulih setelah dialog"
		)
		_check(
			absf(wrapf(float(orbit.get("yaw")) - original_yaw, -PI, PI)) < 0.03,
			"Sudut kamera tidak pulih setelah dialog"
		)
		var restored_focus: Vector3 = orbit.get("focus_offset")
		_check(
			restored_focus.distance_to(original_focus) < 0.03,
			"Titik pandang kamera tidak pulih setelah dialog"
		)
		# Gameplay membuka selector animasi setelah dialog dan kamera selesai menutup.
		player.spawn(Vector2(npc.global_position.x, npc.global_position.z + 1.5))
		interaction.call("_begin_interaction")
		await create_timer(0.65).timeout
		dialogue.call("activate_selected")
		await create_timer(0.85).timeout
		var mode_selector: Control = game.get("_mode_selector")
		_check(mode_selector != null and mode_selector.visible,
			"Gameplay tidak membuka selector mode beranimasi")
		if mode_selector != null:
			var cards: Array = mode_selector.get("_cards")
			_check(cards.size() == 3, "Selector tidak menampilkan Survival, Run Zone, dan placeholder")
			if cards.size() >= 2:
				_check(str(cards[1].get_meta("mode_id", "")) == "run_zone",
					"Pilihan mode kedua tidak terdaftar sebagai Run Zone")
			var mode_status: Label = mode_selector.get("_status")
			mode_selector.call("_select_mode", 2)
			_check(mode_status.text.contains("COMING SOON"),
				"Mode yang belum tersedia tidak menampilkan Coming Soon")
			mode_selector.call("close")
			await create_timer(0.35).timeout
			_check(not mode_selector.visible, "Selector mode tidak menutup")
			_check(bool(joystick.get("input_enabled")) and bool(orbit.get("input_enabled")),
				"Input tidak pulih setelah selector mode")

	game.queue_free()
	await process_frame
	print("[npc-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
