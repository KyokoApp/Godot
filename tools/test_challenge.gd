extends SceneTree
const Character = preload("res://src/game/mannequin.gd")
const FightLibrary = preload("res://src/game/combat/fight_library.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _run() -> void:
	var scene: PackedScene = load("res://src/game/main.tscn")
	var game: Node3D = scene.instantiate()
	root.add_child(game)
	await _frames(3)
	var challenge: Node3D = game._challenge
	# Must not start outside the arena.
	challenge.start()
	_check(not challenge.active, "Mulai di luar arena")

	# Uploaded UAL2 clips must be available and playable on every visible skin.
	for skin in [Character.MANNEQUIN, Character.MIKU, Character.KANNA]:
		_check(game._visual.set_skin(skin), "Skin gagal dimuat: " + skin)
		_check(game._visual.prepare_fight(), "Rig animasi UAL2 gagal disiapkan")
		var driver = game._visual._fight_driver
		for clip in FightLibrary.REQUIRED_CLIPS:
			_check(driver.has_clip(clip), "Klip UAL2 hilang: " + clip)
			if skin == Character.MANNEQUIN:
				var clip_duration: float = driver.play(clip)
				_check(clip_duration > 0.0, "Klip UAL2 tidak bisa dimainkan: " + clip)
				driver.stop()
		var duration: float = game._visual.play_fight(FightLibrary.MELEE)
		_check(duration > 0, "Melee_Hook tidak bisa dimainkan")
		_manual_character_frames(game._visual, 8)
		game._visual.cancel_fight()
	_check(game._visual.set_skin(Character.MANNEQUIN), "Gagal kembali ke mannequin")

	_check(game._visual.set_skin(Character.MIKU), "Gagal pilih Miku untuk pedang")
	game._player.position = Vector3(-145, 9.1, 140)
	game._update_arena_state()
	await _frames(3)
	_check(challenge.prompt.visible, "Prompt tidak muncul")
	_check(challenge.artifact.visible, "Artefak tidak terlihat")
	challenge.start()
	_check(challenge.active, "Tantangan tidak mulai")
	_check(challenge.enemy_hud.visible, "Boss bar musuh tidak muncul")
	_check(challenge.player_hud.visible, "HUD HP pemain tidak muncul")
	_check(challenge.style_button.visible, "Tombol gaya fight tidak muncul")
	_check(challenge.evade_button.visible, "Tombol menghindar tidak muncul")
	_check(challenge.combat_fx is Node3D, "Sistem VFX arena tidak dibuat")
	var effects_before: int = challenge.combat_fx.get_child_count()
	challenge.combat_fx.call("play_swing", game._visual.global_position,
		challenge.enemy.global_position, Color(0.36, 0.82, 1.0), 1.0)
	challenge.combat_fx.call("spawn_impact",
		challenge.enemy.global_position + Vector3.UP, Color(0.36, 0.82, 1.0), 25)
	_check(challenge.combat_fx.get_child_count() == effects_before + 2,
		"VFX tebasan dan benturan tidak muncul")
	_check(challenge.player_hp_bar is ProgressBar, "Bar HP pemain tidak ada")
	_check(challenge.enemy_hp_bar is ProgressBar, "Bar HP musuh tidak ada")
	_check(challenge.enemy_hp_bar.custom_minimum_size.y <= 8, "Boss bar musuh terlalu tebal")
	var boss_rect: Rect2 = challenge.enemy_hp_bar.get_global_rect()
	var viewport_rect: Rect2 = game.get_viewport().get_visible_rect()
	_check(is_equal_approx(boss_rect.get_center().x, viewport_rect.size.x * 0.5),
		"Boss bar tidak di tengah layar")
	_check(boss_rect.position.y < 40, "Boss bar tidak berada di bagian atas layar")
	_check(is_instance_valid(challenge.enemy), "Musuh tidak ada")
	_check(challenge.enemy_visual._fight_driver.has_clip(FightLibrary.MELEE),
		"Musuh tidak memakai klip UAL2")
	_check(challenge.enemy_visual.play_fight_loop(FightLibrary.ZOMBIE_IDLE_LOOP),
		"Loop idle UAL2 tidak dapat dimainkan")
	_check(challenge.enemy_visual.fight_loop, "Loop UAL2 tidak tetap aktif")
	challenge.enemy_visual.cancel_fight()
	# Double-start must be ignored.
	var id: int = challenge.enemy.get_instance_id()
	challenge.start()
	_check(challenge.enemy.get_instance_id() == id, "Musuh duplikat")

	# The hit window expires before the enemy can be reached.
	challenge.set_physics_process(false)
	challenge.enemy.position = game._player.position + Vector3(20, 0, 0)
	challenge.enemy_cooldown = 100.0
	challenge.toggle_attack_style()
	_check(challenge.sword_mode, "Mode pedang tidak aktif")
	_check(game._visual.fight_sword_visible(), "Pedang tidak muncul saat mode pedang")
	_check(game._visual._fight_sword_attachments[Character.MIKU].get_parent()
		== game._visual.retarget.target, "Pedang tidak terpasang ke rig Miku aktif")
	_check(game._visual.set_skin(Character.KANNA), "Gagal mengganti skin saat sword mode")
	_check(game._visual.fight_sword_visible(), "Pedang hilang saat memakai Kanna")
	_check(game._visual._fight_sword_attachments[Character.KANNA].get_parent()
		== game._visual.retarget.target, "Pedang tidak terpasang ke rig Kanna aktif")
	_check(game._visual.set_skin(Character.MIKU), "Gagal kembali ke skin Miku")
	challenge.attack()
	_check(game._visual._fight_driver.animation.current_animation == FightLibrary.SWORD,
		"Sword_Regular_Combo tidak dimainkan")
	_check(challenge.combat_callout.visible, "Nama gerakan arena tidak ditampilkan")
	var sword_pose_start := _pose_snapshot(game._visual.source_skeleton)
	var sword_skin_start := _pose_snapshot(game._visual.retarget.target)
	_check(challenge.enemy_hp == 100, "Hit jarak jauh langsung")
	_step_challenge(challenge, game, 60)
	game._visual.retarget.transfer()
	_check(_pose_changed(game._visual.source_skeleton, sword_pose_start),
		"Pose rig UAL2 tidak berubah pada Sword_Regular_Combo")
	_check(_pose_changed(game._visual.retarget.target, sword_skin_start),
		"Pose skin aktif tidak berubah pada Sword_Regular_Combo")
	_check(challenge.enemy_hp == 100, "Hit jarak jauh terlambat")
	game._visual.cancel_fight()
	challenge.player_cooldown = 0.0
	challenge.attack()
	_check(game._visual._fight_driver.animation.current_animation
		== FightLibrary.SWORD_REGULAR_A, "Combo pedang A dari UAL2 tidak dimainkan")
	game._visual.cancel_fight()
	challenge.player_cooldown = 0.0
	challenge._player_followups.clear()
	challenge.evade()
	_check(game._visual._fight_driver.animation.current_animation
		== FightLibrary.SWORD_BLOCK, "Parry pedang UAL2 tidak dimainkan")
	game._visual.cancel_fight()
	challenge.player_cooldown = 0.0
	challenge._player_followups.clear()
	challenge._player_hit = -1.0
	challenge.toggle_attack_style()
	_check(not challenge.sword_mode, "Mode melee tidak aktif")
	_check(not game._visual.fight_sword_visible(), "Pedang tertinggal di mode melee")
	challenge.evade()
	_check(game._visual._fight_driver.animation.current_animation
		== FightLibrary.SLIDE_START, "Slide_Start UAL2 tidak dimainkan")
	game._visual.cancel_fight()
	challenge.player_cooldown = 0.0
	challenge._player_followups.clear()
	challenge.evade()
	_check(game._visual._fight_driver.animation.current_animation
		== FightLibrary.NINJA_JUMP_START, "NinjaJump_Start UAL2 tidak dimainkan")
	game._visual.cancel_fight()
	challenge.player_cooldown = 0.0
	challenge._player_followups.clear()

	# A close-range melee attack deals 25 damage only after its windup.
	challenge.enemy.position = game._player.position + Vector3(1.5, 0, 0)
	challenge.player_cooldown = 0.0
	challenge.enemy_cooldown = 100.0
	challenge.attack()
	_check(game._visual._fight_driver.animation.current_animation == FightLibrary.MELEE,
		"Melee_Hook tidak dimainkan")
	var melee_pose_start := _pose_snapshot(game._visual.source_skeleton)
	var melee_skin_start := _pose_snapshot(game._visual.retarget.target)
	_check(challenge.player_cooldown > 0, "Cooldown tidak aktif")
	_check(challenge.enemy_hp == 100, "Damage terjadi sebelum windup")
	_step_challenge(challenge, game, 12)
	game._visual.retarget.transfer()
	_check(_pose_changed(game._visual.source_skeleton, melee_pose_start),
		"Pose rig UAL2 tidak berubah pada Melee_Hook")
	_check(_pose_changed(game._visual.retarget.target, melee_skin_start),
		"Pose skin aktif tidak berubah pada Melee_Hook")
	_check(challenge.enemy_hp == 100, "Damage terjadi sebelum windup")
	_step_challenge(challenge, game, 188)
	_check(challenge.enemy_hp == 75, "Damage salah: %d" % challenge.enemy_hp)
	_check(is_equal_approx(challenge.enemy_hp_bar.value, 75), "Bar HP musuh tidak diperbarui")

	# Enemy attacks at close range using the same UAL2 hook clip.
	challenge.enemy_visual.cancel_fight()
	challenge.enemy_cooldown = 0.0
	_step_challenge(challenge, game, 200)
	_check(challenge.player_hp < 100, "Musuh tidak menyerang")
	_check(is_equal_approx(challenge.player_hp_bar.value, challenge.player_hp),
		"Bar HP pemain tidak diperbarui")

	# Victory and cleanup.
	challenge.enemy_hp = 0
	challenge._physics_process(0.016)
	_check(challenge.finishing, "Kemenangan tidak terdeteksi")
	_check(not challenge.enemy_hud.visible and not challenge.player_hud.visible
		and not challenge.style_button.visible, "HUD tidak dibersihkan setelah tantangan")
	_step_challenge(challenge, game, 200)
	_check(not challenge.active and challenge.enemy == null, "Pemenangan tidak bersih")

	# Retry, then leaving the arena cancels the encounter.
	challenge.start()
	_check(challenge.active, "Retry gagal")
	game._player.position = Vector3.ZERO
	game._update_arena_state()
	challenge._physics_process(0.016)
	_check(not challenge.active, "Musuh bertahan setelah keluar arena")
	_check(not challenge.enemy_hud.visible and not challenge.player_hud.visible,
		"Bar HP tertinggal setelah keluar arena")
	_check(not challenge.style_button.visible, "Tombol gaya tertinggal setelah keluar arena")
	_check(game._visual.action_time == 0, "Action lock tertinggal")
	game.queue_free()
	await process_frame
	print("[challenge-test] HASIL: ",
		"OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)


func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _manual_character_frames(character: Node, count: int) -> void:
	for i in range(count):
		character._physics_process(1.0 / 60.0)


func _pose_snapshot(skeleton: Skeleton3D) -> Array[Quaternion]:
	var poses: Array[Quaternion] = []
	for bone in range(skeleton.get_bone_count()):
		poses.append(skeleton.get_bone_pose_rotation(bone))
	return poses


func _pose_changed(skeleton: Skeleton3D, before: Array[Quaternion]) -> bool:
	if before.size() != skeleton.get_bone_count():
		return true
	for bone in range(skeleton.get_bone_count()):
		if not before[bone].is_equal_approx(skeleton.get_bone_pose_rotation(bone)):
			return true
	return false


func _step_challenge(challenge: Node, game: Node, count: int) -> void:
	for i in range(count):
		challenge._physics_process(1.0 / 60.0)
		game._visual._physics_process(1.0 / 60.0)
		if is_instance_valid(challenge.enemy_visual):
			challenge.enemy_visual._physics_process(1.0 / 60.0)
