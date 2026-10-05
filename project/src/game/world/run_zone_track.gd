extends Node3D
## Jalur batu selebar tiga petak; satu PlaneMesh + MultiMesh batu, tanpa collider tambahan.

const PATH_SHADER := preload("res://src/game/world/run_zone_path.gdshader")
const ROCK_SCENE_PATH := "res://assets/nature/models/Rock_Medium_1.gltf"

const TILE_COUNT := 3
const TILE_WIDTH := 2.0
const PATH_WIDTH := float(TILE_COUNT) * TILE_WIDTH
const ROAD_LENGTH := 512.0
const RECENTER_STEP := 8.0
const ROCKS_PER_SIDE := 32
const ROCK_SPACING := 6.0

var path_width := PATH_WIDTH
var road: MeshInstance3D
var rocks: MultiMeshInstance3D
var destroyed_sections: Array[Vector2] = []
var destroyed_rock_count := 0
var _center_z := INF
var _rock_center_step := -2147483648
var _multimesh: MultiMesh


func _ready() -> void:
	name = "RunZoneTrack"
	_build_road()
	_build_rocks()
	_rock_center_step = 0
	_recenter(0.0)
	_refresh_rocks()


func follow_player(player_z: float) -> void:
	var wanted_center := floorf(player_z / RECENTER_STEP) * RECENTER_STEP
	if not is_equal_approx(wanted_center, _center_z):
		_recenter(wanted_center)
	var wanted_rock_step := floori(-player_z / ROCK_SPACING)
	if wanted_rock_step != _rock_center_step:
		_rock_center_step = wanted_rock_step
		_refresh_rocks()


func destroy_area(world_z: float, radius: float) -> void:
	destroyed_sections.append(Vector2(world_z, maxf(radius, 0.0)))
	_refresh_rocks()


func _build_road() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(PATH_WIDTH, ROAD_LENGTH)
	road = MeshInstance3D.new()
	road.name = "ThreeTileStoneRoad"
	road.mesh = plane
	road.position.y = 0.026
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = PATH_SHADER
	road.material_override = material
	add_child(road)


func _build_rocks() -> void:
	var packed := load(ROCK_SCENE_PATH) as PackedScene
	if packed == null:
		push_error("RunZoneTrack: model batu tidak bisa dimuat: " + ROCK_SCENE_PATH)
		return
	var sample := packed.instantiate()
	var rock_mesh: Mesh
	if sample is MeshInstance3D:
		rock_mesh = (sample as MeshInstance3D).mesh
	else:
		for candidate in sample.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := candidate as MeshInstance3D
			if mesh_instance.mesh != null:
				rock_mesh = mesh_instance.mesh
				break
	sample.free()
	if rock_mesh == null:
		push_error("RunZoneTrack: mesh batu kosong")
		return

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.mesh = rock_mesh
	_multimesh.instance_count = ROCKS_PER_SIDE * 2
	rocks = MultiMeshInstance3D.new()
	rocks.name = "RockyRoadSides"
	rocks.multimesh = _multimesh
	rocks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rocks.custom_aabb = AABB(Vector3(-9.0, -2.0, -105.0), Vector3(18.0, 8.0, 210.0))
	add_child(rocks)


func _recenter(center_z: float) -> void:
	_center_z = center_z
	if is_instance_valid(road):
		road.position.z = center_z


func _refresh_rocks() -> void:
	if _multimesh == null:
		return
	destroyed_rock_count = 0
	if is_instance_valid(rocks):
		var world_center_z := -float(_rock_center_step) * ROCK_SPACING
		rocks.custom_aabb = AABB(Vector3(-9.0, -2.0, world_center_z - 105.0),
			Vector3(18.0, 8.0, 210.0))
	var first_step := _rock_center_step - (ROCKS_PER_SIDE >> 1)
	for side_index in range(2):
		var side := -1.0 if side_index == 0 else 1.0
		for row in range(ROCKS_PER_SIDE):
			var instance_index := side_index * ROCKS_PER_SIDE + row
			var world_step := first_step + row
			var world_z := -float(world_step) * ROCK_SPACING
			if _is_destroyed(world_z):
				_multimesh.set_instance_transform(instance_index,
					Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
				destroyed_rock_count += 1
				continue
			var rng := RandomNumberGenerator.new()
			rng.seed = posmod(hash(Vector2i(world_step, side_index)), 2147483646) + 1
			var x := side * rng.randf_range(PATH_WIDTH * 0.5 + 0.95,
				PATH_WIDTH * 0.5 + 1.45)
			var y := rng.randf_range(-0.12, 0.08)
			var rotation := Vector3(rng.randf_range(-0.14, 0.14), rng.randf_range(-PI, PI),
				rng.randf_range(-0.14, 0.14))
			var scale := rng.randf_range(0.95, 1.65)
			var basis := Basis.from_euler(rotation).scaled(Vector3.ONE * scale)
			_multimesh.set_instance_transform(instance_index,
				Transform3D(basis, Vector3(x, y, world_z)))


func _is_destroyed(world_z: float) -> bool:
	for section in destroyed_sections:
		if absf(world_z - section.x) <= section.y:
			return true
	return false
