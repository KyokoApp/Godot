extends Node3D
## Pohon raksasa di pedalaman pulau: penanda arah besar yang terlihat dari seberang
## pulau, sekaligus peneduh yang bayangannya panjang ke arah timur saat senja.
##
## Dibangun PROSEDURAL (satu ArrayMesh, warna per vertex) mengikuti gaya
## scenery.gd: di repo tidak ada aset model pohon sama sekali — folder
## project/assets hanya berisi dua GLB mannequin (UAL1/UAL2) dan dua tekstur
## nature (grass_cards, meadow_cover). Kalau nanti ada GLB pohon, node ini bisa
## diganti tanpa mengubah apa pun yang lain: yang dipakai dari sini hanya
## posisi, tinggi, dan nama node.
##
## Angkanya sengaja besar: 16 m batang + tajuk sampai ~28 m berarti dari jarak
## kamera default 4 m pemain harus menengadah, dan dari zoom terjauh 620 m pohon
## ini masih terlihat sebagai satu titik hijau di tengah pulau.
const Field = preload("res://src/game/world/field.gd")

## Titik tanam. Spawn pemain di (0, 7), jadi 95 m ke utara cukup jauh untuk tidak
## menghalangi pemain, tapi tetap masuk ke layar saat menghadap utara.
const POSITION := Vector3(0.0, 0.0, -95.0)
const TRUNK_HEIGHT := 16.0
const TRUNK_BOTTOM := 2.2
const TRUNK_TOP := 0.85
const TRUNK_SEGMENTS := 12
## Lima cabang utama, masing-masing bercabang sekali lagi.
const BRANCH_COUNT := 5
const BLOB_COUNT := 11
const BLOB_MIN := 3.2
const BLOB_MAX := 5.4
## Batas segitiga supaya pohon ini tidak pernah menyentuh anggaran rumput
## (400 ribu segitiga). Jaringan 8x12 per bola sudah lebih dari cukup dari jauh.
const BLOB_RINGS := 8
const BLOB_SEGMENTS := 12

const BARK := Color("4a3524")
const BARK_LIGHT := Color("6b4f36")
const LEAF_DARK := Color("1d3a17")
const LEAF_MID := Color("2c5423")
const LEAF_LIGHT := Color("3f6b2c")

var trunk: MeshInstance3D
var canopy: MeshInstance3D


func _ready() -> void:
	name = "WorldTree"
	var ground: float = Field.terrain_height(POSITION.x, POSITION.z)
	position = Vector3(POSITION.x, ground, POSITION.z)
	_build_trunk()
	_build_canopy()


## Batang + cabang dalam SATU mesh: satu draw call untuk seluruh rangka pohon.
func _build_trunk() -> void:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var random := RandomNumberGenerator.new()
	random.seed = 20261003
	_add_tapered(vertices, colors, indices, Vector3.ZERO,
		Vector3(0.0, TRUNK_HEIGHT, 0.0), TRUNK_BOTTOM, TRUNK_TOP,
		TRUNK_SEGMENTS, BARK, BARK_LIGHT)
	# Cabang: mulai dari separuh batang, miring ke luar dan ke atas.
	for index in range(BRANCH_COUNT):
		var angle := TAU * float(index) / float(BRANCH_COUNT) + 0.4
		var start_height := TRUNK_HEIGHT * lerpf(0.45, 0.95, random.randf())
		var length := lerpf(5.0, 8.5, random.randf())
		var start := Vector3(0.0, start_height, 0.0)
		var lean := Vector3(cos(angle), 0.0, sin(angle)) * lerpf(0.35, 0.7,
			random.randf())
		lean.y = lerpf(0.55, 0.95, random.randf())
		var tip := start + lean.normalized() * length
		var thick := lerpf(0.55, 0.8, random.randf())
		_add_tapered(vertices, colors, indices, start, tip, thick, thick * 0.45,
			8, BARK_LIGHT, BARK)
		# Satu percabangan lagi supaya tajuknya tidak bertumpu di satu titik.
		var split_angle := angle + random.randf_range(-0.7, 0.7)
		var split := start.lerp(tip, 0.65)
		var second := split + Vector3(cos(split_angle), 0.35,
			sin(split_angle)).normalized() * length * 0.6
		_add_tapered(vertices, colors, indices, split, second, thick * 0.4,
			thick * 0.18, 6, BARK_LIGHT, BARK)
	trunk = _commit(vertices, colors, indices, "Trunk")


## Tajuk: bola-bola hijau yang saling menumpuk. Bentuknya bukan sphere tunggal
## supaya siluetnya tidak beraturan seperti balon.
func _build_canopy() -> void:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var random := RandomNumberGenerator.new()
	random.seed = 77123
	# Dua cincin: bawah lebih lebar (naungan), atas lebih kecil (puncak).
	for index in range(BLOB_COUNT):
		var ring := float(index % 2)
		var around := TAU * float(index) / float(BLOB_COUNT)
		var spread := lerpf(4.6, 7.4, random.randf())
		var centre := Vector3(cos(around) * spread,
			TRUNK_HEIGHT + 4.0 + ring * 3.4 + random.randf() * 2.6,
			sin(around) * spread)
		# Bola tengah sedikit di atas supaya tajuknya punya puncak.
		if index == 0:
			centre = Vector3(0.0, TRUNK_HEIGHT + 8.6, 0.0)
		var radius := lerpf(BLOB_MIN, BLOB_MAX, random.randf())
		var tint: Color = LEAF_LIGHT if random.randf() > 0.6 else LEAF_MID
		if ring > 0.5:
			tint = tint.lightened(0.08)
		_add_blob(vertices, colors, indices, centre, radius, tint, LEAF_DARK)
	canopy = _commit(vertices, colors, indices, "Canopy")


## Silinder runcing dari `start` ke `tip`, warnanya dari bawah ke atas.
func _add_tapered(vertices: PackedVector3Array, colors: PackedColorArray,
		indices: PackedInt32Array, start: Vector3, tip: Vector3,
		bottom: float, top: float, segments: int, low: Color, high: Color) -> void:
	var axis := (tip - start).normalized()
	# Dua vektor tegak lurus axis; yang pertama dipakai sebagai acuan sudut.
	var side := axis.cross(Vector3.UP)
	if side.length() < 0.001:
		side = axis.cross(Vector3.RIGHT)
	side = side.normalized()
	var other := axis.cross(side).normalized()
	var first := vertices.size()
	for step in range(segments + 1):
		var angle := TAU * float(step) / float(segments)
		var offset := side * cos(angle) + other * sin(angle)
		vertices.append(start + offset * bottom)
		vertices.append(tip + offset * top)
		colors.append(low)
		colors.append(high)
	for step in range(segments):
		var a := first + step * 2
		var b := a + 1
		var c := a + 2
		var d := a + 3
		# Urutan (a, c, b) menghasilkan normal ke LUAR: sudah dihitung untuk
		# silinder sepanjang +Y. Kalau dibalik, pohon jadi hitam karena cahaya
		# datang dari arah dalam.
		indices.append_array([a, c, b, b, c, d])


## Bola berjaring (UV sphere) dengan warna atas lebih terang dari bawah, jadi
## bentuknya terbaca bahkan tanpa bayangan.
func _add_blob(vertices: PackedVector3Array, colors: PackedColorArray,
		indices: PackedInt32Array, centre: Vector3, radius: float,
		top: Color, bottom: Color) -> void:
	var first := vertices.size()
	for ring in range(BLOB_RINGS + 1):
		var phi := PI * float(ring) / float(BLOB_RINGS)
		for step in range(BLOB_SEGMENTS + 1):
			var theta := TAU * float(step) / float(BLOB_SEGMENTS)
			var normal := Vector3(sin(phi) * cos(theta), cos(phi),
				sin(phi) * sin(theta))
			vertices.append(centre + normal * radius)
			colors.append(bottom.lerp(top, cos(phi) * 0.5 + 0.5))
	for ring in range(BLOB_RINGS):
		for step in range(BLOB_SEGMENTS):
			var a := first + ring * (BLOB_SEGMENTS + 1) + step
			var b := a + 1
			var c := a + BLOB_SEGMENTS + 1
			var d := c + 1
			# Kebalikan dari silinder: (a, b, c) supaya normal menghadap keluar.
			indices.append_array([a, b, c, b, d, c])


## Satu ArrayMesh dari kumpulan segitiga + warna per vertex (gaya scenery.gd).
func _commit(vertices: PackedVector3Array, colors: PackedColorArray,
		indices: PackedInt32Array, node_name: String) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	add_child(instance)
	return instance
