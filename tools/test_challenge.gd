extends SceneTree
const Character = preload("res://src/game/mannequin.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _frames(count: int) -> void:
	for frame in range(count):
		await physics_frame


func _run() -> void:
	var scene: PackedScene = load("res://src/game/main.tscn")
	var game: Node3D = scene.instantiate()
	root.add_child(game)
	await _frames(4)
	var challenge: Node3D = game._challenge
	challenge.start()
	_check(not challenge.active and challenge.enemy == null, "Challenge starts outside arena")
	game._player.position = Vector3(-145, 9.1, 140)
	game._update_arena_state()
	await _frames(4)
	_check(challenge.prompt.visible and challenge.artifact.visible, "Artifact prompt absent")
	challenge.start()
	_check(challenge.active and is_instance_valid(challenge.enemy), "Start failed")
	if not challenge.active:
		quit(1)
		return
	var id: int = challenge.enemy.get_instance_id()
	challenge.start()
	_check(challenge.enemy.get_instance_id() == id, "Duplicate enemy")
	for name in Character.FightLibrary.CLIPS:
		_check(game._visual.animation.has_animation("fight/" + name), "Missing fight clip " + name)
	for skin in ["miku", "kanna", "mannequin"]:
		game._visual.set_skin(skin)
		var duration: float = game._visual.play_fight("fight/Melee_Hook")
		_check(duration > 0.2, "Fight animation absent on " + skin)
		await _frames(8)
		game._visual.animation.advance(duration * 0.4)
		_check(game._visual.source_skeleton.get_bone_count() > 50, "Rig missing")
	game._visual.cancel_fight()
	# Real animation-clock hit, no damage on button press; no hit out of range.
	challenge.set_physics_process(false)
	challenge.enemy.position = game._player.position + Vector3(5, 0, 0)
	challenge.attack()
	_check(challenge.enemy_hp == 100, "Immediate damage without windup")
	for frame in range(120):
		challenge._physics_process(1.0 / 60)
		challenge.enemy.position = game._player.position + Vector3(5, 0, 0)
	_check(challenge.enemy_hp == 100, "Melee hit outside reach")
	challenge.enemy.position = game._player.position + Vector3(1.8, 0, 0)
	challenge.enemy_cooldown = 100
	challenge.attack()
	for frame in range(120):
		challenge._physics_process(1.0 / 60)
	_check(challenge.enemy_hp == 75, "Attack must hit once for 25 damage")
	challenge.enemy_visual.cancel_fight()
	challenge.enemy_cooldown = 0
	for frame in range(120):
		challenge._physics_process(1.0 / 60)
	_check(challenge.player_hp < 100, "Enemy cannot damage player")
	# Finish, clean up, retry, and cancel on boundary exit.
	challenge.enemy_hp = 0
	challenge._physics_process(0.016)
	_check(challenge.finishing, "Win not detected")
	challenge._physics_process(3)
	await _frames(2)
	_check(not challenge.active and challenge.enemy == null, "Victory did not clean enemy")
	challenge.start()
	_check(challenge.active, "Retry failed")
	game._player.position = Vector3.ZERO
	game._update_arena_state()
	challenge._physics_process(0.016)
	_check(not challenge.active and challenge.enemy == null, "Enemy survives leaving arena")
	_check(game._visual.action_time == 0, "Player remains action locked")
	game.queue_free()
	await process_frame
	print("[challenge-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
