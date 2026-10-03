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
		_check(bool(npc.call("is_walking")), "NPC tidak masuk ke animasi jalan")
		if npc_visual != null:
			_check(
				str(npc_visual.get("clip")) == "Walk_Formal_Loop",
				"NPC memakai klip jalan yang salah: %s" % str(npc_visual.get("clip"))
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
		_check(prompt != null and prompt.visible, "Tombol bicara tidak muncul saat dekat NPC")
		interaction.call("_begin_interaction")
		var dialogue: Control = interaction.get("_dialogue")
		for _frame in range(36):
			await process_frame
		_check(bool(interaction.call("is_open")), "Interaksi tidak membuka layar pilihan")
		_check(dialogue != null and dialogue.visible, "Layar dialog tidak terlihat")
		if dialogue != null:
			var options: Array = dialogue.get("_options")
			_check(options.size() == 4, "Pilihan gameplay tidak lengkap: %d" % options.size())
			_check(dialogue.get("_portrait") != null, "Potret 3D NPC di panel kiri tidak dibuat")
			dialogue.call("move_selection", 1)
			_check(int(dialogue.get("_selected")) == 1, "Navigasi pilihan tidak berpindah")
			dialogue.call("activate_selected")
			var notice: Label = dialogue.get("_notice")
			_check(
				notice != null and notice.text.contains("COMING SOON"),
				"Pilihan gameplay tidak memberi status Coming Soon"
			)
		_check(not bool(joystick.get("input_enabled")), "Joystick aktif saat dialog terbuka")
		_check(not bool(orbit.get("input_enabled")), "Kamera aktif saat dialog terbuka")
		dialogue.call("close_dialogue")
		for _frame in range(24):
			await process_frame
		_check(not bool(interaction.call("is_open")), "Dialog tidak menutup dengan transisi")
		_check(bool(joystick.get("input_enabled")), "Joystick tidak pulih setelah dialog")
		_check(bool(orbit.get("input_enabled")), "Kamera tidak pulih setelah dialog")

	game.queue_free()
	await process_frame
	print("[npc-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
