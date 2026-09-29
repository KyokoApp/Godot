extends SceneTree
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
	for i in range(3):
		await physics_frame
	var challenge: Node3D = game._challenge
	challenge.start()
	_check(not challenge.active, "Mulai di luar arena")
	game._player.position = Vector3(-145, 9.1, 140)
	game._update_arena_state()
	for i in range(3):
		await physics_frame
	_check(challenge.prompt.visible, "Prompt tidak muncul")
	_check(challenge.artifact.visible, "Artefak tidak terlihat")
	challenge.start()
	_check(challenge.active, "Tantangan tidak mulai")
	_check(is_instance_valid(challenge.enemy), "Musuh tidak ada")
	var id: int = challenge.enemy.get_instance_id()
	challenge.start()
	_check(challenge.enemy.get_instance_id() == id, "Musuh duplikat")
	_check(FightLibrary.available(game._visual.animation),
		"Animasi fight tidak ada")
	# Out-of-range cannot hit.
	challenge.set_physics_process(false)
	challenge.enemy.position = game._player.position + Vector3(5, 0, 0)
	challenge.attack()
	_check(challenge.enemy_hp == 100, "Hit jarak jauh")
	for i in range(60):
		challenge._physics_process(1.0 / 60)
	_check(challenge.enemy_hp == 100, "Damage tanpa windup")
	# In-range hit deals 25 damage after windup.
	challenge.enemy.position = game._player.position + Vector3(1.5, 0, 0)
	challenge.enemy_cooldown = 100
	challenge.attack()
	_check(challenge.player_cooldown > 0, "Cooldown tidak aktif")
	for i in range(200):
		challenge._physics_process(1.0 / 60)
	_check(challenge.enemy_hp == 75, "Damage salah: %d" % challenge.enemy_hp)
	# Enemy attacks at close range.
	challenge.enemy_visual.cancel_fight()
	challenge.enemy_cooldown = 0
	for i in range(200):
		challenge._physics_process(1.0 / 60)
	_check(challenge.player_hp < 100, "Musuh tidak menyerang")
	# Victory triggers finish and cleanup.
	challenge.enemy_hp = 0
	challenge._physics_process(0.016)
	_check(challenge.finishing, "Kemenangan tidak terdeteksi")
	for i in range(200):
		challenge._physics_process(1.0 / 60)
	_check(not challenge.active and challenge.enemy == null, "Cleanup gagal")
	challenge.start()
	_check(challenge.active, "Retry gagal")
	# Leaving arena cancels.
	game._player.position = Vector3.ZERO
	game._update_arena_state()
	challenge._physics_process(0.016)
	_check(not challenge.active, "Musuh bertahan keluar arena")
	_check(game._visual.action_time == 0, "Action lock tertinggal")
	game.queue_free()
	await process_frame
	print("[challenge-test] HASIL: ",
		"OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
