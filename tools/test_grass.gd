extends SceneTree
## Digunakan dua kali: logika headless dan render Mobile/Vulkan via Mesa/Xvfb.

const Island = preload("res://src/game/island.gd")
const Grass = preload("res://src/game/grass_field.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var island := Island.new()
	world.add_child(island)
	var player := Node3D.new()
	player.position = Vector3(45, island.surface_height(45, 0) + 0.9, 0)
	world.add_child(player)
	var field := Grass.new()
	field.island = island
	field.player = player
	world.add_child(field)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = player.position + Vector3(0, 3, 6)
	camera.look_at(player.position)
	camera.current = true
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 20, 0)
	world.add_child(sun)
	for z in range(-330, 331, 10):
		_check(not field.can_grow(Island.road_x(z), z), "Rumput tumbuh di jalan")
	_check(not field.can_grow(490, 490), "Rumput tumbuh di laut")
	_check(not field.can_grow(420, 0), "Rumput tumbuh di pantai")
	_check(not field.can_grow(310, -110), "Rumput tumbuh di sisi tebing")
	for rock in island.rock_clearances:
		_check(not field.can_grow(rock.x, rock.z), "Rumput tumbuh di batu")
	for frame in range(35):
		await process_frame
	_check(field.tiles.size() == Grass.MAX_TILES, "Jumlah tile tidak sesuai batas")
	var total := 0
	for tile in field.tiles.values():
		total += tile.multimesh.instance_count
		for index in range(tile.multimesh.instance_count):
			var point: Vector3 = tile.position + tile.multimesh.get_instance_transform(index).origin
			_check(field.can_grow(point.x, point.z), "Penempatan di area terlarang")
			_check(absf(point.y + 0.03 - island.surface_height(point.x, point.z)) < 0.01,
				"Akar rumput mengambang")
	_check(total > 100, "Tidak ada padang rumput yang cukup untuk dirender")
	_check(total <= 10000, "Budget rumput terlampaui")
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		_check(image != null and not image.is_empty(), "Render menghasilkan gambar kosong")
		image.save_png("user://grass-render-test.png")
	# Jalan jauh tidak menumpuk tile dari posisi sebelumnya.
	player.position = Vector3(-130, island.surface_height(-130, 40) + 0.9, 40)
	for frame in range(35):
		await process_frame
	_check(field.tiles.size() <= Grass.MAX_TILES, "Tile lama bocor setelah berpindah")
	for key in field.tiles:
		_check(absi(key.x - floori(player.position.x / Grass.TILE_SIZE)) <= Grass.RADIUS,
			"Tile jauh tidak dilepas")
	print("[grass-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
