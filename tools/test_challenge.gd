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


func _frames(count: int) -> void:
	for i in range(count):
		await physics_frame


func _run() -> void:
	var scene: PackedScene = load("res://src/game/main.tscn")
	var game: Node3D = scene.instantiate()
	root.add_child(game)
	await _frames(3)
	var challenge: Node3D = game._challenge
	# Must not start outside arena.
	challenge.start()
	_check(not challenge.active, "Mulai di luar arena")
	game._player.position = Vector3(-145, 9.1, 140)
	game._update_arena_state()
	await _frames(3)
	_check(challenge.prompt.visible, "Prompt tidak muncul")
	_check(challenge.artifact.visible, "Artefak tidak terlihat")
	challenge.start()
	_check(challenge.active, "Tantangan tidak mulai")
	_check(is_instance_valid(challenge.enemy), "Musuh tidak ada")
	# Double-start must be ignored.
	var id: int = challenge.enemy.get_instance_id()
	challenge.start()
	_check(challenge.enemy.get_instance_id() == id, "Musuh duplikat")
	# Verify combat animations load.
	_check(FightLibrary.install(game._visual.animation), "Combat lib gagal")
	for clip in [FightLibrary.PUNCH, FightLibrary.HIT, FightLibrary.DEATH]:
		_check(game._visual.animation.has_animation("combat/" + clip),
			"Anim hilang: " + clip)
	# Out-of-range must not hit.
	challenge.set_physics_process(false)
	challenge.enemy.position = game._player.position + Vector3(5, 0, 0)
	challenge.attack()
	_check(challenge.enemy_hp == 100, "Hit jarak jauh")
	for i in range(200):
		challenge._physics_process(1.0 / 60)
	_check(challenge.enemy_hp == 100, "Musuh hit tanpa windup")
	# In-range hit after windup.
	challenge.enemy.position = game._player.position + Vector3(1.5, 0, 0)
	challenge.enemy_cooldown = 100
	challenge.attack()
	_check(challenge.player_cooldown > 0, "Cooldown tidak aktif")
	await _frames(200)
	_check(challenge.enemy_hp == 75, "Damage salah: %d" % challenge.enemy_hp)
	# Enemy cannot attack when cooldown reset.
	challenge.enemy_visual.cancel_fight()
	challenge.enemy_cooldown = 0
	await _frames(200)
	_check(challenge.player_hp < 100, "Musuh tidak menyerang")
	# Victory.
	challenge.enemy_hp = 0
	challenge._physics_process(0.016)
	_check(challenge.finishing, "Kemenangan tidak terdeteksi")
	await _frames(200)
	_check(not challenge.active and challenge.enemy == null, "Pemenangan tidak bersih")
	# Retry.
	challenge.start()
	_check(challenge.active, "Retry gagal")
	# Leaving arena cancels.
	game._player.position = Vector3.ZERO
	game._update_arena_state()
	challenge._physics_process(0.016)
	_check(not challenge.active, "Musuh bertahan setelah keluar arena")
	_check(game._visual.action_time == 0, "Action lock tertinggal")
	game.queue_free()
	await process_frame
	print("[challenge-test] HASIL: ",
		"OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
