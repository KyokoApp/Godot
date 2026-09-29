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
	var blade_mesh: ArrayMesh = field.get("_mesh")
	var arrays := blade_mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	_check(indices.size() == 18, "Budget 6 segitiga per rumpun berubah")
	_check(Grass.MAX_TRIANGLES <= 112000,
		"Kepadatan baru melampaui budget LOD")
	_check(Grass.BLADE_WIDTH < 0.1, "Helai rumput masih terlalu lebar")
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
	for key in field.tiles:
		var tile: MultiMeshInstance3D = field.tiles[key]
		var placements := field.placements_for(key)
		total += tile.multimesh.instance_count
		_check(placements.size() == tile.multimesh.instance_count, "Jumlah instance berbeda")
		for index in range(placements.size()):
			var placement: Transform3D = placements[index]
			# Renderer dummy tidak menyimpan transform MultiMesh di GPU.
			# Readback GPU hanya diuji pada pass render Vulkan, bukan headless.
			if "--render" in OS.get_cmdline_user_args():
				placement = tile.multimesh.get_instance_transform(index)
				_check(placement.is_equal_approx(placements[index]), "Transform GPU berbeda")
			var point: Vector3 = tile.position + placement.origin
			_check(field.can_grow(point.x, point.z), "Penempatan di area terlarang")
			_check(absf(point.y + 0.03 - island.surface_height(point.x, point.z)) < 0.01,
				"Akar rumput mengambang")
	_test_cover(field)
	_test_lod_subset(field)
	_check(total > 100, "Tidak ada padang rumput yang cukup untuk dirender")
	_check(total <= Grass.MAX_CLUMPS, "Budget rumput terlampaui")
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		_check(image != null and not image.is_empty(), "Render menghasilkan gambar kosong")
		image.save_png("user://grass-render-test.png")
		await _test_two_sided_lighting()
	# Jalan jauh tidak menumpuk tile dari posisi sebelumnya.
	player.position = Vector3(-130, island.surface_height(-130, 40) + 0.9, 40)
	for frame in range(35):
		await process_frame
	_check(field.tiles.size() <= Grass.MAX_TILES, "Tile lama bocor setelah berpindah")
	for key in field.tiles:
		_check(absi(key.x - floori(player.position.x / Grass.TILE_SIZE)) <= Grass.RADIUS,
			"Tile jauh tidak dilepas")
	# Melintasi satu batas tile harus tetap di bawah budget selama transisi LOD.
	player.position.x += Grass.TILE_SIZE
	for frame in range(35):
		await process_frame
		var triangles := 0
		for tile in field.tiles.values():
			var tris := 6 if tile.multimesh.mesh == blade_mesh else 4
			triangles += tile.multimesh.instance_count * tris
		_check(triangles <= Grass.MAX_TRIANGLES, "Budget terlampaui saat transisi LOD")
	print("[grass-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)


func _test_two_sided_lighting() -> void:
	# Dua kartu identik dengan winding berlawanan: harus sama terang pada renderer
	# Mobile. Tes lama hanya memastikan gambar ada, sehingga backface hitam lolos.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 128)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color.BLACK
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.25
	environment.environment = settings
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees.x = -90
	world.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.8
	camera.position = Vector3(0, 0.5, 4)
	world.add_child(camera)
	camera.current = true
	var material := ShaderMaterial.new()
	material.shader = Grass.SHADER
	material.set_shader_parameter("wind_strength", 0.0)
	material.set_shader_parameter("player_position", Vector3(0, 0, 5))
	var image := Image.create(2, 2, false, Image.FORMAT_RGB8)
	image.fill(Color(0.5, 0.5, 0.5))
	material.set_shader_parameter("wind_noise", ImageTexture.create_from_image(image))
	for index in range(2):
		var card := MeshInstance3D.new()
		card.mesh = _lighting_card(index == 1)
		card.material_override = material
		card.position.x = -0.65 if index == 0 else 0.65
		world.add_child(card)
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var rendered := viewport.get_texture().get_image()
	var left := camera.unproject_position(Vector3(-0.65, 0.5, 0))
	var right := camera.unproject_position(Vector3(0.65, 0.5, 0))
	var front := rendered.get_pixel(int(left.x), int(left.y))
	var back := rendered.get_pixel(int(right.x), int(right.y))
	_check(front.g > 0.30 and back.g > 0.30, "Salah satu sisi rumput masih gelap")
	_check(absf(front.get_luminance() - back.get_luminance()) < 0.025,
		"Cahaya depan/belakang rumput tidak setara")
	print("::notice::Grass lighting baru: depan=", front, " belakang=", back)
	# A/B hanya di tes: reproduksi shader lama untuk memastikan tes menangkap bug.
	var legacy := Shader.new()
	legacy.code = Grass.SHADER.code.replace(
		"NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);", "")
	material.shader = legacy
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	rendered = viewport.get_texture().get_image()
	front = rendered.get_pixel(int(left.x), int(left.y))
	back = rendered.get_pixel(int(right.x), int(right.y))
	_check(absf(front.get_luminance() - back.get_luminance()) > 0.05,
		"Tes A/B tidak mereproduksi perbedaan normal shader lama")
	print("::notice::Grass lighting lama: depan=", front, " belakang=", back)
	viewport.queue_free()


func _lighting_card(reverse: bool) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(-0.3, 0, 0), Vector3(0.3, 0, 0), Vector3(-0.3, 1, 0), Vector3(0.3, 1, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([
		Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0, 1), Vector2(1, 1), Vector2(0, 0), Vector2(1, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 1, 3, 2] if not reverse
		else [0, 2, 1, 1, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _test_cover(field: Node3D) -> void:
	var key := Vector2i(3, 0)
	var placements: Array[Transform3D] = field.placements_for(key)
	var origin := Vector3(key.x * Grass.TILE_SIZE, 0, key.y * Grass.TILE_SIZE)
	var checked := 0
	var covered := 0
	for z in range(1, 10):
		for x in range(1, 10):
			var point := origin + Vector3(x + 0.17, 0, z + 0.23)
			if not field.can_grow(point.x, point.z):
				continue
			if Vector2(point.x - 45.0, point.z).length() > 7.5:
				continue
			checked += 1
			for placement in placements:
				var local := placement.affine_inverse() * (point - origin)
				if absf(local.x) <= Grass.COVER_HALF_SIZE and absf(local.z) <= Grass.COVER_HALF_SIZE:
					covered += 1
					break
	_check(checked > 30, "Sampel area hijau tidak cukup untuk tes penutup tanah")
	_check(covered >= checked * 0.95, "Penutup tanah dekat belum mencapai 95% sampel")
	print("::notice::Ground cover: ", covered, "/", checked, " sampel tertutup")


func _test_lod_subset(field: Node3D) -> void:
	var saved: Vector2i = field.get("_center")
	var near: Array[Transform3D] = field.placements_for(saved)
	var origins: Dictionary[Vector3, bool] = {}
	for placement in near:
		origins[placement.origin] = true
	field.set("_center", saved + Vector2i(2, 0))
	var far: Array[Transform3D] = field.placements_for(saved)
	field.set("_center", saved)
	_check(far.size() < near.size(), "LOD jauh tidak mengurangi kepadatan")
	for placement in far:
		_check(origins.has(placement.origin), "Akar berpindah saat ganti LOD")
