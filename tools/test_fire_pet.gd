extends SceneTree

const Pet = preload("res://src/game/fire_pet.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _run() -> void:
	var scene: PackedScene = load("res://src/game/main.tscn")
	var game: Node3D = scene.instantiate()
	root.add_child(game)
	for frame in range(3):
		await physics_frame
	var pet: Pet = game.get("_pet")
	_check(pet.get_parent() == game, "Pet menempel pada rig, bukan node dunia")
	var delta := pet.global_position - pet.player.global_position
	_check(Vector2(delta.x, delta.z).length() >= 0.84, "Pet terlalu dekat dengan karakter")
	_check(delta.y > 0.3 and delta.y < 0.85, "Pet tidak sejajar bahu")
	var start := pet.global_position
	for frame in range(25):
		await physics_frame
	_check(pet.global_position.distance_to(start) > 0.005, "Pet tidak beranimasi melayang")
	var orbit: Node3D = game.get("_orbit")
	var attack: Button = game.get("_attack")
	var touch := InputEventScreenTouch.new()
	touch.index = 9
	touch.pressed = true
	touch.position = attack.get_global_rect().get_center()
	orbit._input(touch)
	_check(orbit.get("_touches").is_empty(), "Attack ikut memutar kamera")
	_check(pet.attack(), "Serangan pertama gagal")
	_check(not pet.attack(), "Cooldown tidak mencegah spam")
	var shot: CharacterBody3D = pet.projectiles[0]
	var vertical := shot.velocity.y
	await physics_frame
	await physics_frame
	_check(shot.velocity.y < vertical, "Proyektil tidak dipengaruhi gravitasi")
	var exploded := false
	for frame in range(240):
		await physics_frame
		pet._prune()
		exploded = exploded or not pet.bursts.is_empty()
	_check(exploded, "Proyektil tidak meledak saat menabrak terrain")
	_check(pet.projectiles.is_empty(), "Proyektil tidak dibersihkan")
	_check(pet.bursts.is_empty(), "Ledakan tidak dibersihkan")
	for index in range(4):
		pet.cooldown = 0
		pet.attack()
	_check(pet.projectiles.size() <= Pet.MAX_PROJECTILES, "Batas proyektil terlampaui")
	for index in range(5):
		pet._on_impact(pet.global_position + Vector3(0, 0, -3), Vector3.UP)
	_check(pet.bursts.size() <= Pet.MAX_BURSTS, "Batas ledakan terlampaui")
	print("[fire-pet-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
