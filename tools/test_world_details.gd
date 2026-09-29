extends SceneTree
## Placement, budgets, archived resources, masks, conservative occluders and lifecycle.

const Library = preload("res://src/game/world/nature_library.gd")
const Nature = preload("res://src/game/world/nature_field.gd")
const DistantGrass = preload("res://src/game/world/distant_grass.gd")
const Island = preload("res://src/game/island.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _run() -> void:
	for asset in Library.ASSETS:
		var parts := Library.parts(asset)
		_check(not parts.is_empty(), "Mesh asli hilang: " + asset)
		for part: Dictionary in parts:
			var mesh: Mesh = part["mesh"]
			_check(mesh.get_surface_count() > 0, "Surface kosong: " + asset)
			for index in range(mesh.get_surface_count()):
				var material := mesh.surface_get_material(index) as StandardMaterial3D
				_check(material != null and material.albedo_texture != null,
					"Tekstur glTF tidak terhubung: " + asset)
	var scene: PackedScene = load("res://src/game/main.tscn")
	var game := scene.instantiate() as Node3D
	root.add_child(game)
	for frame in range(60):
		await process_frame
	var nature: Nature = game.get("_nature")
	var grass: Node3D = game.get("_grass")
	var distant: DistantGrass = grass.get("distant")
	var island: Island = game.get("_island")
	_check(nature.tiles.size() == Nature.MAX_TILES, "Nature streaming belum lengkap")
	_check(distant.tiles.size() == DistantGrass.MAX_TILES, "LOD kartu belum lengkap")
	_check(DistantGrass.MAX_TRIANGLES <= 28224, "LOD kartu melebihi budget")
	_check(game.get("_stone_path").piece_count > 200, "Setapak model lama belum dipasang")
	_check(root.use_occlusion_culling, "Occlusion culling belum aktif")
	var environment: Environment = game.get_node("NightEnvironment").environment
	_check(environment.fog_enabled and not environment.volumetric_fog_enabled,
		"Kabut seharusnya tipis non-volumetric")
	_check(environment.fog_sky_affect == 0, "Kabut menutupi bulan/bintang")
	var total := 0
	for key in nature.tiles:
		var placements := nature.placements_for(key)
		_check(placements == nature.placements_for(key), "Penempatan nature tidak deterministik")
		_check(placements.size() <= Nature.TREE_ATTEMPTS + Nature.DETAIL_ATTEMPTS,
			"Budget per sel nature terlampaui")
		total += placements.size()
		for placement in placements:
			var point: Vector3 = placement["position"]
			_check(nature.can_place(Vector2(point.x, point.z), placement["tree"]),
				"Nature masuk jalan/air/lereng curam")
			_check(absf(point.y - island.surface_height(point.x, point.z)) < 0.01,
				"Model melayang di atas tanah")
	_check(total > 40, "Pulau masih terlalu kosong")
	for key in distant.tiles:
		for placement in distant.placements_for(key):
			var point := placement.origin + Vector3(key.x * DistantGrass.TILE, 0,
				key.y * DistantGrass.TILE)
			_check(grass.can_grow(point.x, point.z), "Kartu rumput masuk jalan/laut/batu")
	_test_occluder(island)
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://world-nature-test.png")
	var player: Node3D = game.get("_player")
	player.position = Vector3(-170, island.surface_height(-170, 70) + 0.9, 70)
	for frame in range(60):
		await process_frame
	_check(nature.tiles.size() <= Nature.MAX_TILES, "Sel nature lama bocor setelah teleport")
	_check(distant.tiles.size() <= DistantGrass.MAX_TILES, "Kartu jauh bocor setelah teleport")
	var center := Vector2i(floori(player.position.x / Nature.TILE),
		floori(player.position.z / Nature.TILE))
	for key in nature.tiles:
		_check(maxi(absi(key.x - center.x), absi(key.y - center.y)) <= Nature.RADIUS,
			"Sel nature tertinggal jauh dari pemain")
	game.queue_free()
	await process_frame
	_check(not root.use_occlusion_culling, "Pengaturan occlusion bocor setelah keluar")
	print("[world-details-test] nature near spawn: ", total)
	print("[world-details-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)


func _test_occluder(island: Island) -> void:
	var node := island.get_node("TerrainOcclusion") as OccluderInstance3D
	var shape := node.occluder as ArrayOccluder3D
	_check(shape.indices.size() / 3 <= 5000, "Occluder terrain terlalu rumit")
	_check(shape.vertices.size() > 100, "Occluder terrain kosong")
	for index in range(0, shape.vertices.size(), 4):
		var origin := shape.vertices[index]
		for z in range(0, 21, 5):
			for x in range(0, 21, 5):
				_check(origin.y <= island.surface_height(origin.x + x, origin.z + z) - 0.49,
					"Occluder melintasi udara, berisiko menghilangkan objek terlihat")
