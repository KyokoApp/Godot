extends Node3D
## Dedaunan Quaternius (CC0) yang dulu ADA di project ini lalu hilang — sekarang
## kembali. Modelnya diambil dari arsip lama pengguna di repo `KyokoApp/Unity`
## (`Assets/WorldSrc/`): pohon, pinus, semak, pakis, bunga, dan batu. Provenance
## lengkap ada di `project/licenses/LICENSES.txt`.
##
## Semuanya MultiMeshInstance3D: satu panggilan gambar per model, bukan satu node
## per objek. Itu sebabnya 100-an dedaunan bisa masuk tanpa memukul draw call —
## sama seperti rumput, dan sama seperti saran culling/LOD yang sudah dipakai.
##
## Tidak ada collision (sama seperti pemandangan lain): pemain akan menembus
## dedaunan. Biaya fisika tetap nol, dan pulau cuma 100 m jadi menembus semak
## tidak terasa seperti bug seberapa pun.

const Field = preload("res://src/game/world/field.gd")

## Titik muncul pemain (harus sama dengan main.gd): tidak ada dedaunan di sini
## supaya pemain tidak muncul di dalam semak.
const SPAWN := Vector2(0.0, 7.0)

## Satu baris per jenis: model, jumlah, rentang skala, jarak minimum dari garis
## pantai, dan jarak minimum antar objek (0 = boleh rapat).
## Skala pohon sengaja diturunkan: model aslinya 7-9 m, di pulau 100 m itu
## terbaca seperti menara, bukan pohon.
const SETS := [
	{
		"paths": [
			"res://assets/nature/models/CommonTree_1.gltf",
			"res://assets/nature/models/CommonTree_3.gltf",
			"res://assets/nature/models/Pine_1.gltf",
		],
		"count": 16,
		"scale_min": 0.45,
		"scale_max": 0.8,
		"margin": 2.5,
		"spacing": 3.2,
		"shadow": true,
	},
	{
		"paths": [
			"res://assets/nature/models/Bush_Common.gltf",
			"res://assets/nature/models/Bush_Common_Flowers.gltf",
		],
		"count": 26,
		"scale_min": 0.7,
		"scale_max": 1.15,
		"margin": 1.5,
		"spacing": 1.2,
		"shadow": false,
	},
	{
		"paths": [
			"res://assets/nature/models/Rock_Medium_1.gltf",
			"res://assets/nature/models/Rock_Medium_2.gltf",
			"res://assets/nature/models/Pebble_Round_1.gltf",
		],
		"count": 18,
		"scale_min": 0.5,
		"scale_max": 1.1,
		"margin": 1.0,
		"spacing": 1.0,
		"shadow": false,
	},
	{
		"paths": [
			"res://assets/nature/models/Fern_1.gltf",
			"res://assets/nature/models/Flower_3_Group.gltf",
		],
		"count": 44,
		"scale_min": 0.8,
		"scale_max": 1.15,
		"margin": 1.0,
		"spacing": 0.0,
		"shadow": false,
	},
]

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	# Benih tetap: bentuk pulau dan sebaran dedaunan harus sama setiap kali
	# permainan dijalankan, kalau tidak tangkapan layar tes jadi tidak stabil.
	_rng.seed = 20261003
	for spec: Dictionary in SETS:
		_scatter(spec)


func _scatter(spec: Dictionary) -> void:
	var spots := _candidates(int(spec["count"]), float(spec["margin"]),
		float(spec.get("spacing", 0.0)))
	if spots.is_empty():
		return
	var paths: Array = spec["paths"]
	var index := 0
	for path: String in paths:
		var share: Array = []
		while index < spots.size() and share.size() < ceili(float(spots.size()) / float(paths.size())):
			share.append(spots[index])
			index += 1
		if not share.is_empty():
			_build_one(path, share, spec)


## Titik yang boleh ditanami: di darat kering, tidak di jalan tanah, tidak
## menempel garis pantai, tidak terlalu curam, dan tidak menutupi titik muncul.
func _candidates(count: int, margin: float, spacing: float) -> Array:
	var result: Array = []
	var guard := 0
	var limit := maxi(count * 120, 600)
	while result.size() < count and guard < limit:
		guard += 1
		# Sebaran merata lewat kotak + penolakan: titik acak di kotak ± 45 m,
		# yang jatuh di laut dibuang oleh is_inside() di bawah. Lebih rata
		# daripada sampling lingkaran, dan tidak butuh akar kuadrat.
		var x := _rng.randf_range(-45.0, 45.0)
		var z := _rng.randf_range(-45.0, 45.0)
		if not Field.is_inside(x, z, margin):
			continue
		if absf(z - Field.path_centre(x)) < 1.6:
			continue
		if Vector2(x, z).distance_to(SPAWN) < 3.0:
			continue
		var gradient := Vector2(
			Field.terrain_height(x + 0.5, z) - Field.terrain_height(x - 0.5, z),
			Field.terrain_height(x, z + 0.5) - Field.terrain_height(x, z - 0.5)).length()
		if gradient > 0.35:
			continue
		if spacing > 0.0 and _too_close(result, x, z, spacing):
			continue
		result.append({"x": x, "y": Field.terrain_height(x, z), "z": z})
	return result


func _too_close(spots: Array, x: float, z: float, spacing: float) -> bool:
	for spot: Dictionary in spots:
		if Vector2(x, z).distance_to(Vector2(spot["x"], spot["z"])) < spacing:
			return true
	return false


func _build_one(path: String, spots: Array, spec: Dictionary) -> void:
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_error("Forest: model tidak bisa dimuat: " + path)
		return
	var sample: Node = scene.instantiate()
	var mesh_instance := sample.find_child("MeshInstance3D", true, false) as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null:
		sample.free()
		push_error("Forest: model tanpa mesh: " + path)
		return
	var mesh: Mesh = mesh_instance.mesh
	sample.free()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = spots.size()
	for index in spots.size():
		var spot: Dictionary = spots[index]
		var factor := _rng.randf_range(float(spec["scale_min"]), float(spec["scale_max"]))
		var basis := Basis.from_euler(Vector3(0.0, _rng.randf() * TAU, 0.0))
		basis = basis.scaled(Vector3.ONE * factor)
		multimesh.set_instance_transform(index,
			Transform3D(basis, Vector3(spot["x"], spot["y"], spot["z"])))
	var node := MultiMeshInstance3D.new()
	node.name = path.get_file().get_basename()
	node.multimesh = multimesh
	# Bayangan cuma untuk pohon: semak, batu, dan bunga terlalu kecil untuk
	# terlihat di peta bayangan, tapi tetap membayar biaya menggambarnya.
	if bool(spec.get("shadow", false)):
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	else:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func summary() -> String:
	var parts := PackedStringArray()
	for node: MultiMeshInstance3D in find_children("*", "MultiMeshInstance3D", false, false):
		parts.append("%s:%d" % [node.name, node.multimesh.instance_count])
	return ", ".join(parts)
