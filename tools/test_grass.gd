extends SceneTree
## Rumput di pulau 1 km: anggaran LOD, penempatan di tanah, LOD turun saat jauh.

const Field = preload("res://src/game/world/field.gd")
const FirePet = preload("res://src/game/fire_pet.gd")
const Character = preload("res://src/game/mannequin.gd")
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
	var ground := Field.new()
	world.add_child(ground)
	var player := Node3D.new()
	# Titik ini harus bisa DITANAMI rumput (can_grow). Dulu (12, -6) — itu kini
	# tepat di dalam kolam tengah (radius air 21 m), jadi tile rumputnya kosong
	# dan tes gagal dengan "Tile dekat kosong".
	player.position = Vector3(30, ground.surface_height(30, -30) + 0.9, -30)
	world.add_child(player)
	var character := Character.new()
	character.position = player.position - Vector3(0, 0.9, 0)
	world.add_child(character)
	var field := Grass.new()
	field.ground = ground
	field.player = player
	world.add_child(field)
	var blade_mesh: ArrayMesh = field.get("_mesh")
	var arrays := blade_mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	_check(indices.size() == 18, "Budget 6 segitiga per rumpun berubah")
	_check(Grass.MAX_TRIANGLES <= 336864, "Kepadatan baru melampaui budget LOD")
	_check(Grass.BLADE_WIDTH < 0.1, "Helai rumput masih terlalu lebar")
	# Helai rapat harus sampai 24 m (5x5 tile), bukan berhenti di 12 m.
	_check(Grass.NEAR_SPAN * 2 + 1 == 5, "Cakupan helai rapat menyusut")
	# Helai harus KECIL: tinggi di bawah setengah tinggi lama (0,55 m).
	_check(Grass.BLADE_HEIGHT < 0.4, "Helai rumput masih setinggi semak")
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = player.position + Vector3(0, 3, 6)
	camera.look_at(player.position)
	camera.current = true
	var pet := FirePet.new()
	pet.player = player
	pet.facing = character
	pet.camera = camera
	world.add_child(pet)
	pet._on_impact(player.position + Vector3(2, 0, -3), Vector3.UP)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 20, 0)
	world.add_child(sun)
	# Rumput hanya di daratan pulau: tidak di laut, tidak menembus garis pantai,
	# dan tidak di kolam tengah (ronde 18: kolam itu sengaja dibiarkan polos).
	# Titik uji pindah dari (0,0)/(-14,10) — keduanya kini berada di dalam kolam
	# radius 22 m — ke dataran dalam di luar lekukan kolam.
	_check(field.can_grow(-14, 40), "Rumput tidak tumbuh di dataran dalam")
	_check(field.can_grow(30, 30), "Rumput tidak tumbuh di dataran timur")
	_check(not field.can_grow(0, 0), "Rumput tumbuh di kolam tengah")
	_check(not field.can_grow(0, 20), "Rumput tumbuh di bibir kolam")
	for angle in [0.0, 1.1, 2.2, 3.3, 4.4, 5.5]:
		var coast := Field.island_radius(angle) + 25.0
		_check(not field.can_grow(cos(angle) * coast, sin(angle) * coast),
			"Rumput tumbuh di laut pada sudut %.1f" % angle)
	var shore_angle := 0.7
	var shore_radius := Field.island_radius(shore_angle) - 2.0
	_check(not field.can_grow(cos(shore_angle) * shore_radius,
		sin(shore_angle) * shore_radius),
		"Rumput tumbuh menempel garis pantai (pasir harus polos)")
	for _sample in range(40):
		var x := randf_range(-Field.HALF, Field.HALF)
		var z := randf_range(-Field.HALF, Field.HALF)
		if ground.can_grow(x, z):
			_check(Field.is_inside(x, z, 0.0), "Penempatan rumput di luar pulau")
	# 49 tile dibangun satu per frame, jadi butuh 49 frame (bukan 35).
	for frame in range(60):
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
			if "--render" in OS.get_cmdline_user_args():
				placement = tile.multimesh.get_instance_transform(index)
				_check(placement.is_equal_approx(placements[index]), "Transform GPU berbeda")
			var point: Vector3 = tile.position + placement.origin
			_check(field.can_grow(point.x, point.z), "Penempatan di area terlarang")
			_check(absf(point.y + 0.03 - ground.surface_height(point.x, point.z)) < 0.01,
				"Akar rumput mengambang")
	_test_lod_subset(field, Vector2i(2, -3))
	_check(total > 100, "Tidak ada padang rumput yang cukup untuk dirender")
	_check(total <= Grass.MAX_CLUMPS, "Budget rumput terlampaui")
	if "--render" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		_check(image != null and not image.is_empty(), "Render menghasilkan gambar kosong")
		image.save_png("user://grass-render-test.png")
		await _test_two_sided_lighting()
	# Tile jauh dilepas saat pemain berpindah ke sisi lain padang.
	player.position = Vector3(-12, ground.surface_height(-12, -14) + 0.9, -14)
	for frame in range(35):
		await process_frame
	_check(field.tiles.size() <= Grass.MAX_TILES, "Tile lama bocor setelah berpindah")
	for key in field.tiles:
		_check(absi(key.x - floori(player.position.x / Grass.TILE_SIZE)) <= Grass.RADIUS,
			"Tile jauh tidak dilepas")
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


func _test_lod_subset(field: Grass, tile: Vector2i) -> void:
	# Tile yang dipakai harus tile PEMAIN (yang berisi rumput). Dulu (0, 0) —
	# itu sekarang tepat di tengah kolam, jadi tile-nya kosong.
	var near := field.placements_for(tile)
	_check(not near.is_empty(), "Tile dekat kosong")
	# Grid jauh adalah subset grid dekat supaya akar tidak melompat saat LOD turun.
	var far_count := 0
	for placement in near:
		var cell_x := floori(placement.origin.x * Grass.GRID / Grass.TILE_SIZE)
		var cell_z := floori(placement.origin.z * Grass.GRID / Grass.TILE_SIZE)
		if cell_x % 2 == 0 and cell_z % 2 == 0:
			far_count += 1
	_check(far_count > 0 and far_count < near.size(),
		"Subset LOD jauh tidak masuk akal: %d dari %d" % [far_count, near.size()])


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
