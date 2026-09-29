extends SceneTree

const Island = preload("res://src/game/island.gd")
const Orbit = preload("res://src/game/orbit_camera.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _touch(orbit: Node3D, index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	orbit._input(event)


func _drag(orbit: Node3D, index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	orbit._input(event)


func _run() -> void:
	var island := Island.new()
	root.add_child(island)
	_check(island._color(300, 0, 50, Vector3.UP).is_equal_approx(Island.GRASS_COLOR),
		"Puncak datar tidak hijau")
	_check(island._color(300, 0, 50, Vector3.RIGHT).is_equal_approx(Island.CLIFF_COLOR),
		"Sisi tebing tidak berwarna batu")
	_check(island._color(0, 0, 5, Vector3.UP).is_equal_approx(Island.DIRT_COLOR),
		"Jalan tidak berwarna tanah")
	var terrain_materials := 0
	for child in island.get_children():
		if child is MeshInstance3D:
			var material := child.material_override as StandardMaterial3D
			if material != null and material.vertex_color_use_as_albedo:
				terrain_materials += 1
				_check(material.vertex_color_is_srgb, "Warna terrain salah ruang warna")
	_check(terrain_materials == 16, "Material chunk terrain hilang")
	_check(Island.SIZE == 1000.0, "Ukuran map bukan 1 km")
	_check(Island.terrain_height(500, 500) < 0, "Sudut map tidak berada di laut")
	_check(Island.terrain_height(230, -110) > 40, "Tebing tidak terbentuk")
	for z in range(-290, 291, 10):
		var x := Island.road_x(z)
		_check(absf(island.surface_height(x, z) - Island.road_height(z)) < 0.2,
			"Permukaan jalan tidak mengikuti terrain")
	for frame in range(3):
		await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(Vector3(0, 100, 0), Vector3(0, -10, 0), 1)
	var hit := island.get_world_3d().direct_space_state.intersect_ray(ray)
	_check(not hit.is_empty(), "Collider tanah tidak kena ray dari atas")
	if not hit.is_empty():
		var position: Vector3 = hit["position"]
		var normal: Vector3 = hit["normal"]
		_check(absf(position.y - island.surface_height(0, 0)) < 0.1, "Collider beda dari mesh")
		_check(normal.y > 0.9, "Normal tanah terbalik")
	var orbit := Orbit.new()
	root.add_child(orbit)
	var width := root.get_visible_rect().size.x
	var point := Vector2(width * 0.7, 200)
	_touch(orbit, 0, Vector2(width * 0.2, 200), true)
	_drag(orbit, 0, point)
	_check(is_zero_approx(orbit.yaw), "Sentuhan kiri mengubah kamera")
	_touch(orbit, 1, point, true)
	_drag(orbit, 1, point + Vector2(100, 10000))
	_check(not is_zero_approx(orbit.yaw), "Swipe kanan tidak mengubah yaw")
	_check(is_equal_approx(orbit.pitch, Orbit.MAX_PITCH), "Pitch melewati batas")
	orbit.reset_touches()
	_touch(orbit, 1, point, true)
	_touch(orbit, 2, point + Vector2(100, 0), true)
	var yaw := orbit.yaw
	_drag(orbit, 2, point + Vector2(400, 0))
	_check(is_equal_approx(orbit.distance, Orbit.MIN_DISTANCE), "Pinch tidak zoom dekat")
	_check(is_equal_approx(orbit.yaw, yaw), "Pinch ikut memutar kamera")
	orbit.yaw = PI / 2
	_check(orbit.movement_direction(Vector2.UP).is_equal_approx(Vector3.LEFT),
		"Gerak tidak mengikuti kamera")
	orbit.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(orbit.get("_touches").is_empty(), "Sentuhan kamera tersangkut")
	# Kamera harus dipendekkan oleh SpringArm saat ada tembok di belakang pemain.
	orbit.yaw = 0
	orbit.pitch = 0.30
	orbit.distance = Orbit.DEFAULT_DISTANCE
	orbit.position = Vector3(0, 100, 0)
	orbit.follow(orbit.position, 1.0)
	var wall := StaticBody3D.new()
	wall.position = Vector3(0, 101, 2)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.5)
	collider.shape = box
	wall.add_child(collider)
	root.add_child(wall)
	for frame in range(5):
		await physics_frame
	_check(orbit.arm.get_hit_length() < 2.0, "Kamera menembus penghalang")
	print("[island-camera-test] gagal: ", _failures)
	quit(0 if _failures == 0 else 1)
