extends SceneTree
const Island = preload("res://src/game/island.gd")
const Arena = preload("res://src/game/arena/battle_arena.gd")
const Grass = preload("res://src/game/grass_field.gd")
const Nature = preload("res://src/game/world/nature_field.gd")
const Night = preload("res://src/game/environment/night_environment.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var island := Island.new()
	world.add_child(island)
	var arena := Arena.new()
	world.add_child(arena)
	var grass := Grass.new()
	grass.island = island
	var nature := Nature.new()
	nature.island = island
	var center := Arena.Shape.CENTER
	for z in range(-30, 31, 10):
		for x in range(-30, 31, 10):
			if Vector2(x, z).length() > 34:
				continue
			var p := center + Vector2(x, z)
			_check(absf(island.surface_height(p.x, p.y) - Arena.Shape.HEIGHT) < 0.01,
				"Arena floor tidak rata")
			_check(not grass.can_grow(p.x, p.y), "Rumput masuk arena")
			_check(not nature.can_place(p, true), "Pohon masuk arena")
			_check(island.is_walkable_shore(p.x, p.y), "Arena tertutup air")
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(center.x, 30, center.y), Vector3(center.x, 0, center.y), 1)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	_check(not hit.is_empty(), "Collider arena hilang")
	if not hit.is_empty():
		_check(absf(hit.position.y - Arena.Shape.HEIGHT) < 0.02, "Collider beda dari tanah")
	var env := WorldEnvironment.new()
	env.environment = Night.make_environment()
	world.add_child(env)
	world.add_child(Night.make_moonlight())
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(center.x + 48, 65, center.y + 65)
	camera.look_at(Vector3(center.x, 9, center.y))
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("user://motion-arena-test.png")
	_check(image.get_pixel(240, 135) != image.get_pixel(210, 135), "Tanah arena polos")
	grass.free()
	nature.free()
	world.queue_free()
	await process_frame
	print("[arena-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
