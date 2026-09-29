extends Node3D
## Skin kain biru: rig asli menggerakkan torso/lengan, rok memakai Verlet terbatas.
## 64 partikel, 3 iterasi, collision kaki + lantai. Bukan simulasi fluida api.

const FABRIC = preload("res://src/game/blue_flame_cloth.gdshader")
const OUTLINE = preload("res://src/game/character_outline.gdshader")
const SIDES := 16
const ROWS := 4
const ITERATIONS := 3
const REQUIRED_BONES: Array[String] = ["pelvis", "spine_03", "neck_01", "Head",
	"upperarm_l", "lowerarm_l", "hand_l", "upperarm_r", "lowerarm_r", "hand_r",
	"thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r"]

var terrain: Node3D
var skeleton: Skeleton3D
var points := PackedVector3Array()
var previous := PackedVector3Array()
var ready_to_wear := false
var _bones: Dictionary[String, int] = {}
var _pose: Dictionary[String, Vector3] = {}
var _edges: Array[Vector3] = []
var _mesh := ArrayMesh.new()
var _cloth: MeshInstance3D
var _material: ShaderMaterial
var _hood: MeshInstance3D
var _face: MeshInstance3D
var _hands: Array[MeshInstance3D] = []
var _boots: Array[MeshInstance3D] = []
var _last_hip := Vector3.ZERO
var _time := 0.0
var _vertices := PackedVector3Array()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()


func _ready() -> void:
	name = "BlueFlameRobe"
	if skeleton == null:
		return
	for bone in REQUIRED_BONES:
		var index := skeleton.find_bone(bone)
		if index < 0:
			push_error("Jubah: tulang tidak ditemukan: " + bone)
			return
		_bones[bone] = index
	_material = ShaderMaterial.new()
	_material.shader = FABRIC
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE
	outline.set_shader_parameter("outline_width", 0.004)
	_material.next_pass = outline
	_cloth = MeshInstance3D.new()
	_cloth.name = "RobeCloth"
	_cloth.mesh = _mesh
	_cloth.material_override = _material
	add_child(_cloth)
	_build_accessories()
	_sample_pose()
	_reset_cloth()
	_build_constraints()
	ready_to_wear = true
	_update_mesh()


func _sample_pose() -> void:
	for bone in REQUIRED_BONES:
		_pose[bone] = skeleton.to_global(skeleton.get_bone_global_pose(_bones[bone]).origin)


func _target(row: int, side: int) -> Vector3:
	var fraction := float(row) / (ROWS - 1)
	var angle := side * TAU / SIDES
	var radius := lerpf(0.27, 0.49, fraction)
	var local := Vector3(sin(angle) * radius, -fraction * 0.83,
		cos(angle) * radius * 0.95)
	# Pin pada pelvis; arah rok mengikuti arah karakter, posisi simulasi tetap world-space.
	return _pose["pelvis"] + global_basis * local


func _reset_cloth() -> void:
	points.resize(ROWS * SIDES)
	previous.resize(ROWS * SIDES)
	for row in range(ROWS):
		for side in range(SIDES):
			var index := row * SIDES + side
			points[index] = _target(row, side)
			previous[index] = points[index]
	_last_hip = _pose["pelvis"]


func _build_constraints() -> void:
	for row in range(ROWS):
		for side in range(SIDES):
			var a := row * SIDES + side
			_add_edge(a, row * SIDES + (side + 1) % SIDES)
			if row < ROWS - 1:
				_add_edge(a, a + SIDES)
				_add_edge(a, (row + 1) * SIDES + (side + 1) % SIDES)


func _add_edge(a: int, b: int) -> void:
	_edges.append(Vector3(a, b, points[a].distance_to(points[b])))


func _physics_process(delta: float) -> void:
	if not ready_to_wear:
		return
	_sample_pose()
	var hip: Vector3 = _pose["pelvis"]
	if hip.distance_to(_last_hip) > 2.0:
		_reset_cloth()
	_last_hip = hip
	_time += delta
	var step := minf(delta, 1.0 / 30.0)
	for index in range(SIDES, points.size()):
		var position_before := points[index]
		var velocity := (points[index] - previous[index]) * 0.94
		var goal := _target(index / SIDES, index % SIDES)
		var force := Vector3(sin(_time * 1.6 + index * 0.3) * 0.6, -3.0, 0.25)
		force += (goal - points[index]) * 42.0
		points[index] += velocity + force * step * step
		previous[index] = position_before
	for iteration in range(ITERATIONS):
		for side in range(SIDES):
			points[side] = _target(0, side)
		for edge in _edges:
			_solve_edge(int(edge.x), int(edge.y), edge.z)
		_collide()
	_update_mesh()


func _solve_edge(a: int, b: int, rest: float) -> void:
	var offset := points[b] - points[a]
	var length := offset.length()
	if length < 0.00001:
		return
	var correction := offset * (1.0 - rest / length)
	if a < SIDES:
		if b >= SIDES:
			points[b] -= correction
	elif b < SIDES:
		points[a] += correction
	else:
		points[a] += correction * 0.5
		points[b] -= correction * 0.5


func _collide() -> void:
	var floor_y := global_position.y + 0.06
	for index in range(SIDES, points.size()):
		var point := points[index]
		for side in ["l", "r"]:
			point = _outside_capsule(point, _pose["thigh_" + side], _pose["calf_" + side], 0.16)
			point = _outside_capsule(point, _pose["calf_" + side], _pose["foot_" + side], 0.14)
		# Batas lokal mencegah kain terbang jauh setelah tabrakan/putaran mendadak.
		var goal := _target(index / SIDES, index % SIDES)
		point = goal + (point - goal).limit_length(0.30)
		var ground := floor_y
		if terrain != null:
			ground = maxf(ground, float(terrain.call("surface_height", point.x, point.z)) + 0.04)
		point.y = maxf(point.y, ground)
		points[index] = point


func _outside_capsule(point: Vector3, a: Vector3, b: Vector3, radius: float) -> Vector3:
	var axis := b - a
	var ratio := clampf((point - a).dot(axis) / maxf(axis.length_squared(), 0.00001), 0, 1)
	var closest := a + axis * ratio
	var offset := point - closest
	if offset.length_squared() < radius * radius:
		var normal := offset.normalized() if offset.length_squared() > 0.00001 else Vector3.RIGHT
		return closest + normal * radius
	return point


func _update_mesh() -> void:
	_vertices.clear()
	_uvs.clear()
	_indices.clear()
	# Rok yang disimulasikan, seam UV digandakan agar pola api tidak melompat.
	for row in range(ROWS):
		for side in range(SIDES + 1):
			_vertices.append(to_local(points[row * SIDES + side % SIDES]))
			_uvs.append(Vector2(float(side) / SIDES, float(row) / (ROWS - 1)))
	_strip(0, ROWS, SIDES)
	# Torso longgar tersambung ke ring pelvis; tidak mengubah rig sumber.
	var start := _vertices.size()
	var centers: Array[Vector3] = [_pose["neck_01"], _pose["spine_03"], _pose["pelvis"]]
	var widths: Array[float] = [0.19, 0.31, 0.27]
	for row in range(3):
		for side in range(SIDES + 1):
			var angle := side * TAU / SIDES
			var offset := Vector3(sin(angle) * widths[row], 0, cos(angle) * widths[row] * 0.95)
			_vertices.append(to_local(centers[row]) + offset)
			_uvs.append(Vector2(float(side) / SIDES, float(row) * 0.22))
	_strip(start, 3, SIDES)
	for side in ["l", "r"]:
		_sleeve(side)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	# Mesh kecil: normal dihitung ulang hanya pada tick fisika.
	var source := ArrayMesh.new()
	source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := SurfaceTool.new()
	surface.create_from(source, 0)
	surface.generate_normals()
	_mesh.clear_surfaces()
	surface.commit(_mesh)
	_update_accessories()


func _strip(start: int, rows: int, sides: int) -> void:
	for row in range(rows - 1):
		for side in range(sides):
			var a := start + row * (sides + 1) + side
			var b := a + sides + 1
			_indices.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))


func _sleeve(side: String) -> void:
	var start := _vertices.size()
	var centers: Array[Vector3] = [to_local(_pose["upperarm_" + side]),
		to_local(_pose["lowerarm_" + side]), to_local(_pose["hand_" + side])]
	for row in range(3):
		var direction := (centers[mini(row + 1, 2)] - centers[maxi(row - 1, 0)]).normalized()
		var across := direction.cross(Vector3.FORWARD).normalized()
		if across.length_squared() < 0.01:
			across = Vector3.RIGHT
		var other := direction.cross(across).normalized()
		var radius := 0.15 if row != 2 else 0.19
		for side_index in range(9):
			var angle := side_index * TAU / 8.0
			_vertices.append(centers[row] + (across * sin(angle) + other * cos(angle)) * radius)
			_uvs.append(Vector2(side_index / 8.0, row / 2.0))
	_strip(start, 3, 8)


func _build_accessories() -> void:
	_hood = _ellipsoid("Hood", Vector3(0.24, 0.28, 0.23), _material)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("29445e")
	dark.roughness = 1.0
	_face = _ellipsoid("HoodOpening", Vector3(0.155, 0.19, 0.045), dark)
	var pale := StandardMaterial3D.new()
	pale.albedo_color = Color("badfea")
	pale.roughness = 1.0
	for side in ["Left", "Right"]:
		_hands.append(_ellipsoid(side + "Glove", Vector3(0.075, 0.10, 0.075), pale))
		_boots.append(_ellipsoid(side + "Boot", Vector3(0.10, 0.12, 0.17), dark))


func _ellipsoid(label: String, size: Vector3, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = label
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	visual.mesh = sphere
	visual.scale = size
	visual.material_override = material
	add_child(visual)
	return visual


func _update_accessories() -> void:
	var head := to_local(_pose["Head"]) + Vector3(0, 0.13, 0)
	_hood.position = head
	_face.position = head + Vector3(0, -0.015, -0.22)
	for index in range(2):
		var side := "l" if index == 0 else "r"
		_hands[index].position = to_local(_pose["hand_" + side]) + Vector3(0, -0.045, 0)
		_boots[index].position = to_local(_pose["foot_" + side]) + Vector3(0, 0.03, -0.04)
