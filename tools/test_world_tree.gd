extends SceneTree
## Gerbang pohon raksasa: pohon harus berdiri di DARAT (bukan terapung atau di
## laut), cukup tinggi untuk jadi penanda arah dari seberang pulau, dan murah
## (tidak boleh menyentuh anggaran 400 ribu segitiga rumput).
##
## Pemeriksaan terakhir lewat render: tajuk harus terbaca HIJAU dan tidak hitam
## pekat. Itu menangkap winding segitiga yang terbalik — kalau normal menghadap
## ke dalam, cahaya datang dari dalam pohon dan seluruh tajuk jadi hitam, dan itu
## memang kesalahan yang mudah terjadi saat menulis bola tangan pertama.
const WorldTree = preload("res://src/game/world/world_tree.gd")
const Field = preload("res://src/game/world/field.gd")
const Dusk = preload("res://src/game/environment/dusk_environment.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _run() -> void:
	var tree := WorldTree.new()
	root.add_child(tree)
	for _frame in range(4):
		await process_frame
	var ground: float = Field.terrain_height(WorldTree.POSITION.x,
		WorldTree.POSITION.z)
	_check(absf(tree.position.y - ground) < 0.01,
		"Pohon tidak menempel tanah: y=%.3f, tanah=%.3f" % [tree.position.y, ground])
	_check(ground > 0.0, "Pohon tumbuh di laut (tinggi tanah %.2f)" % ground)
	var trunk := tree.get_node("Trunk") as MeshInstance3D
	var canopy := tree.get_node("Canopy") as MeshInstance3D
	_check(trunk != null and canopy != null, "Batang atau tajuk tidak terbentuk")
	var top: float = canopy.get_aabb().end.y
	_check(top > 20.0, "Pohon terlalu pendek untuk jadi penanda arah: %.1f m" % top)
	var lowest: float = trunk.get_aabb().position.y
	_check(lowest <= 0.05, "Batang menggantung di atas tanah: %.2f m" % lowest)
	var triangles := _triangles(trunk) + _triangles(canopy)
	_check(triangles < 20000,
		"Pohon terlalu berat: %d segitiga (batas 20000)" % triangles)
	# Render: tajuk harus terlihat dan tetap hijau (bukan hitam karena normal
	# segitiga menghadap ke dalam).
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Dusk.make_environment()
	world.add_child(environment)
	var sun := Dusk.make_sunlight()
	world.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, -Dusk.SUN_DIRECTION)
	var camera := Camera3D.new()
	camera.fov = 60.0
	camera.position = WorldTree.POSITION + Vector3(0.0, ground + 7.0, 26.0)
	world.add_child(camera)
	camera.current = true
	camera.look_at(WorldTree.POSITION + Vector3(0.0, ground + 19.0, 0.0))
	for _frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var with_tree: Image = root.get_texture().get_image()
	with_tree.save_png("user://world-tree-test.png")
	canopy.visible = false
	for _frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	var without: Image = root.get_texture().get_image()
	canopy.visible = true
	var changed := 0
	var green := 0
	var black := 0
	for y in range(0, with_tree.get_height(), 2):
		for x in range(0, with_tree.get_width(), 2):
			var a := with_tree.get_pixel(x, y)
			var b := without.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.02:
				changed += 1
				if a.g > a.r and a.g > a.b:
					green += 1
				if a.get_luminance() < 0.02:
					black += 1
	_check(changed > 40, "Tajuk pohon tidak terlihat di render (%d piksel)" % changed)
	_check(green > changed * 0.25,
		"Tajuk tidak terbaca hijau: %d dari %d piksel" % [green, changed])
	_check(black < changed * 0.3,
		"Sebagian tajuk hitam pekat (%d dari %d) — kemungkinan normal segitiga "
		% [black, changed] + "menghadap ke dalam")
	print("[world-tree-test] tinggi=%.1f m segitiga=%d piksel-tajuk=%d hijau=%d"
		% [top, triangles, changed, green])
	print("[world-tree-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)


## Jumlah segitiga sebuah mesh (surface 0), dihitung dari panjang array index.
func _triangles(mesh_instance: MeshInstance3D) -> int:
	var mesh := mesh_instance.mesh
	if mesh == null:
		return 0
	var indices: Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	return indices.size() / 3
