extends SceneTree
## Shared watershed/collider/placement and real Mobile depth+SSR rendering regression.

const Island = preload("res://src/game/island.gd")
const Shape = preload("res://src/game/water/water_shape.gd")
const Surfaces = preload("res://src/game/water/water_surfaces.gd")
const WaterMaterial = preload("res://src/game/water/water_material.gd")
const Night = preload("res://src/game/environment/night_environment.gd")
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
	var game := scene.instantiate() as Node3D
	root.add_child(game)
	for frame in range(3):
		await physics_frame
	game.set_physics_process(false)
	var island: Island = game.get("_island")
	var grass: Node3D = game.get("_grass")
	var nature: Node3D = game.get("_nature")
	_check(island.water.triangle_count > 1000, "Mesh air kosong")
	_check(island.water.triangle_count <= Surfaces.MAX_TRIANGLES, "Budget mesh air terlampaui")
	_check(island.water.get_child_count() < 70, "Air terlalu banyak draw surfaces")
	for z in range(-290, 291, 5):
		for side: float in [-8.0, 0.0, 8.0]:
			var x := Island.road_x(z) + side
			_check(Shape.distance_to_water(x, z) > 22, "Watershed memotong jalan")
			_check(island.is_walkable_shore(x, z), "Jalan menjadi tidak bisa dilewati")
	var samples: Array[Vector2] = [Shape.LAKE_CENTER]
	for z in range(-40, 301, 10):
		samples.append(Vector2(Shape.river_x(z), z))
	for point in samples:
		var ground := island.surface_height(point.x, point.y)
		_check(ground < Shape.level(point.x, point.y) - 0.4, "Aliran sungai terputus tanah")
		_check(not island.is_walkable_shore(point.x, point.y), "Pemain dapat tenggelam")
		_check(not grass.can_grow(point.x, point.y), "Rumput tumbuh dalam air")
		_check(not nature.can_place(point, true), "Pohon tumbuh dalam air")
		var ray := PhysicsRayQueryParameters3D.create(Vector3(point.x, 120, point.y),
			Vector3(point.x, -10, point.y), 1)
		var hit := island.get_world_3d().direct_space_state.intersect_ray(ray)
		_check(not hit.is_empty(), "Dasar danau/sungai tidak punya collision")
		if not hit.is_empty():
			var position: Vector3 = hit["position"]
			_check(absf(position.y - ground) < 0.02, "Collider bukan permukaan visual")
	for rock in island.rock_clearances:
		_check(not Shape.covers(rock.x, rock.z, 5), "Batu besar membendung sungai")
	# Uniformly sample banks too, not only the centerline.
	for z in range(-110, 311, 5):
		for x in range(25, 301, 5):
			if Shape.covers(x, z):
				_check(not grass.can_grow(x, z), "Rumput masuk tepian air")
				_check(not nature.can_place(Vector2(x, z), false), "Semak masuk tepian air")
	var panel: Node = game.get("_performance")
	panel.water_ssr = false
	panel.apply_settings()
	_check(island.water.inland_material.get_shader_parameter("ssr_enabled") == false,
		"Mode ringan masih raymarch")
	panel.water_ssr = true
	panel.apply_settings()
	_check(island.water.inland_material.get_shader_parameter("ssr_enabled") == true,
		"Pilihan SSR tidak mencapai material")
	_check(island.water.ocean_material.get_shader_parameter("ssr_enabled") == false,
		"Ocean ikut SSR tanpa batas")
	panel.water_ssr = false
	panel.apply_settings()
	if "--render" in OS.get_cmdline_user_args():
		await _render_world(game, island)
	game.queue_free()
	for frame in range(5):
		await process_frame
	if "--render" in OS.get_cmdline_user_args():
		await _render_fixture()
	print("[water-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)


func _capture() -> Image:
	for frame in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _difference(first: Image, second: Image, threshold := 0.025) -> int:
	var count := 0
	for y in range(first.get_height()):
		for x in range(first.get_width()):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() > threshold:
				count += 1
	return count


func _render_world(game: Node3D, island: Island) -> void:
	var camera := Camera3D.new()
	game.add_child(camera)
	camera.current = true
	camera.position = Vector3(88, 67, 52)
	camera.look_at(Vector3(110, 3, -43))
	game.get("_grass").set_process(false)
	game.get("_nature").set_process(false)
	island.water.inland_material.set_shader_parameter("animation_speed", 0.0)
	var lake: Image = await _capture()
	lake.save_png("user://water-lake-test.png")
	island.water.hide()
	var dry: Image = await _capture()
	var pixels := _difference(lake, dry)
	_check(pixels > 500, "Danau tidak benar-benar dirender")
	print("[water-test] lake pixels=", pixels, " triangles=", island.water.triangle_count)
	island.water.show()
	camera.position = Vector3(235, 62, 115)
	camera.look_at(Vector3(Shape.river_x(110), 1, 110))
	var river: Image = await _capture()
	river.save_png("user://water-river-test.png")
	camera.position = Vector3(250, 155, 370)
	camera.look_at(Vector3(170, 0, 70))
	var watershed: Image = await _capture()
	watershed.save_png("user://water-watershed-test.png")


func _render_fixture() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Night.make_environment()
	environment.environment.fog_enabled = false
	world.add_child(environment)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 3, 8)
	camera.look_at(Vector3(0, 0, -4))
	camera.current = true
	var ground := _box(world, Vector3(0, -2.8, -8), Vector3(40, 1, 40), Color("708558"))
	var landmark := _box(world, Vector3(0, 2, -7), Vector3(3, 5, 2), Color("ff7960"))
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(35, 35)
	water.mesh = plane
	var material := WaterMaterial.create()
	material.set_shader_parameter("animation_speed", 0.0)
	water.material_override = material
	world.add_child(water)
	var cheap: Image = await _capture()
	cheap.save_png("user://water-fallback-test.png")
	material.set_shader_parameter("ssr_enabled", true)
	var ssr: Image = await _capture()
	ssr.save_png("user://water-ssr-test.png")
	var reflected := _difference(cheap, ssr, 0.008)
	_check(reflected > 20, "SSR tidak menghasilkan pantulan objek opaque")
	material.set_shader_parameter("ssr_enabled", false)
	# A real transparent-water check: changing the submerged bed must affect pixels.
	var ground_material := ground.material_override as StandardMaterial3D
	ground_material.albedo_color = Color("617ae8")
	var blue_bed: Image = await _capture()
	_check(_difference(cheap, blue_bed) > 100, "Transparansi/depth air tidak bekerja")
	landmark.hide()
	material.set_shader_parameter("ssr_enabled", true)
	var miss: Image = await _capture()
	miss.save_png("user://water-miss-test.png")
	var center := miss.get_pixel(miss.get_width() / 2, miss.get_height() * 3 / 4)
	_check(center.b > 0.03, "SSR miss menjadikan air hitam")
	# Exercise camera near/far changes, not a hardcoded depth-linearization pair.
	camera.near = 0.25
	camera.far = 350
	var different_planes: Image = await _capture()
	_check(_difference(miss, different_planes) < 200, "Depth bergantung near/far hardcoded")
	print("[water-test] SSR changed pixels=", reflected)
	world.queue_free()
	for frame in range(5):
		await process_frame


func _box(parent: Node3D, position: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = position
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	visual.material_override = material
	parent.add_child(visual)
	return visual
