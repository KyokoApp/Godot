extends Node3D
## Kolam tengah pulau: air CETek bergelombang dengan sebuah pintu berdiri di air
## (referensi anime Suzume). Semuanya prosedural — tidak ada aset baru.
##
## Air memakai water.gdshader yang SAMA dengan laut, hanya parameter gelombang
## dan warnanya yang lebih tenang. Pintunya punya "pantulan" tiruan: salinan
## terbalik di bawah permukaan air, karena renderer Mobile tidak punya SSR
## (screen-space reflection hanya ada di Forward+).

const Field = preload("res://src/game/world/field.gd")
const WATER_SHADER = preload("res://src/game/world/water.gdshader")
const Dusk = preload("res://src/game/environment/dusk_environment.gd")

## Jari-jari bidang air (meter). Garis air sebenarnya ada di mana tanah melintasi
## POND_LEVEL — sekitar 21 m dari pusat (dasar kolam 3,4 m naik landai sampai
## dataran 5 m). Bidang air sengaja dibuat 21 m supaya tepinya tidak pernah
## menjorok ke daratan kering dan terlihat mengambang di atas rumput.
const WATER_RADIUS := 21.0
## Cincin dan juring mesh air: 24 x 64 = 3 ribu segitiga, cukup halus untuk
## gelombang yang terlihat di kolam selebar 42 m.
const RINGS := 24
const SEGMENTS := 64
## Ukuran pintu (meter).
const DOOR_HEIGHT := 3.8
const DOOR_WIDTH := 1.9

var water: MeshInstance3D
var door: Node3D
var reflection: Node3D


func _ready() -> void:
	name = "Pond"
	_build_water()
	_build_door()


# ------------------------------------------------------------------- air ----

func _build_water() -> void:
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("sun_direction", Dusk.SUN_DIRECTION)
	# Kolam tenang: gelombang lebih pendek dan lebih pendek tingginya dari laut.
	material.set_shader_parameter("wave_height", 0.055)
	material.set_shader_parameter("wave_length", 5.0)
	material.set_shader_parameter("wave_speed", 0.55)
	material.set_shader_parameter("depth_fade", 0.7)
	material.set_shader_parameter("depth_full", 2.6)
	# Kolam ada di tengah pulau, bukan di ufuk: campuran ufuk dimatikan supaya
	# warnanya tidak ikut memudar seperti laut jauh.
	material.set_shader_parameter("horizon_fade", 400.0)
	material.set_shader_parameter("shallow_color",
		Color(0.10, 0.20, 0.24))
	material.set_shader_parameter("deep_color", Color(0.03, 0.09, 0.14))
	water = MeshInstance3D.new()
	water.name = "PondWater"
	water.mesh = _make_disc(WATER_RADIUS, RINGS, SEGMENTS)
	water.material_override = material
	water.position = Vector3(0.0, Field.POND_LEVEL, 0.0)
	# Air tidak melindungi bayangan: bayangan pintu sudah ada di pintunya.
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


## Cakram berjajaran kutub (cincin x juring). Dipakai supaya bidang airnya
## BUNDAR, bukan kotak, dan pusatnya lebih rapat (di situ gelombang paling
## terlihat karena pintunya berdiri di tengah).
func _make_disc(radius: float, rings: int, segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var normals := PackedVector3Array()
	vertices.append(Vector3.ZERO)
	normals.append(Vector3.UP)
	for ring in range(1, rings + 1):
		var r := radius * float(ring) / float(rings)
		for seg in range(segments):
			var angle := TAU * float(seg) / float(segments)
			vertices.append(Vector3(cos(angle) * r, 0.0, sin(angle) * r))
			normals.append(Vector3.UP)
	# Kipas tengah. Urutan [0, a, b] supaya bidang menghadap ATAS.
	for seg in range(segments):
		indices.append_array(PackedInt32Array([0, 1 + seg, 1 + (seg + 1) % segments]))
	# Antar cincin: dua segitiga per sel.
	for ring in range(1, rings):
		var inner := 1 + (ring - 1) * segments
		var outer := 1 + ring * segments
		for seg in range(segments):
			var a := inner + seg
			var b := inner + (seg + 1) % segments
			var c := outer + seg
			var d := outer + (seg + 1) % segments
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# ----------------------------------------------------------------- pintu ----

## Bagian pintu sebagai daftar (posisi, ukuran, peran). Dibuat sekali lalu
## dipakai dua kali: pintu asli dan pantulan tiruannya.
func _door_parts() -> Array:
	var half := DOOR_WIDTH * 0.5
	var post := 0.22
	return [
		{"pos": Vector3(-half + post * 0.5, DOOR_HEIGHT * 0.5, 0.0),
			"size": Vector3(post, DOOR_HEIGHT, post), "role": "frame"},
		{"pos": Vector3(half - post * 0.5, DOOR_HEIGHT * 0.5, 0.0),
			"size": Vector3(post, DOOR_HEIGHT, post), "role": "frame"},
		{"pos": Vector3(0.0, DOOR_HEIGHT + 0.14, 0.0),
			"size": Vector3(DOOR_WIDTH + post * 2.0, 0.3, post * 1.3), "role": "frame"},
		# Ambang: pijakan di dasar pintu, setinggi sedikit di atas air.
		{"pos": Vector3(0.0, 0.12, 0.0),
			"size": Vector3(DOOR_WIDTH + post * 2.0, 0.24, post * 2.2), "role": "step"},
		# Daun pintu, sedikit terbuka seperti pintu Suzume yang ditinggalkan.
		{"pos": Vector3(-0.16, 1.62, 0.04),
			"size": Vector3(DOOR_WIDTH - post - 0.34, 2.96, 0.1), "role": "leaf"},
		{"pos": Vector3(0.44, 1.62, -0.02),
			"size": Vector3(DOOR_WIDTH - post - 0.34, 2.96, 0.1), "role": "leaf"},
		# Cahaya dari celah pintu: inilah yang membuat bloom menyala di air.
		{"pos": Vector3(0.14, 1.5, 0.11),
			"size": Vector3(0.1, 2.7, 0.06), "role": "glow"},
	]


func _build_door() -> void:
	var floor_height := Field.terrain_height(0.0, 0.0)
	door = Node3D.new()
	door.name = "Door"
	door.position = Vector3(0.0, floor_height, 0.0)
	add_child(door)
	for part: Dictionary in _door_parts():
		door.add_child(_make_block(part, false))
	# Pantulan tiruan: salinan terbalik di bawah permukaan air. Air kolam cuma
	# sekitar 0,9 m dalam, jadi pantulan setinggi aslinya akan terkubur tanah —
	# karena itu tingginya DIMPATKAN (squash) supaya tetap terbaca di antara
	# dasar kolam dan permukaan air, persis seperti pantulan di air cetek.
	var above := Field.POND_LEVEL - floor_height
	var squash := 0.35
	reflection = Node3D.new()
	reflection.name = "DoorReflection"
	reflection.position = Vector3(0.0, floor_height, 0.0)
	add_child(reflection)
	for part: Dictionary in _door_parts():
		var part_pos: Vector3 = part["pos"]
		var part_size: Vector3 = part["size"]
		# Bagian yang sudah tenggelam tidak dipantulkan.
		if part_pos.y + part_size.y * 0.5 <= above:
			continue
		# Tipe harus eksplisit: `part` bertipe Dictionary, tapi `duplicate()`
		# mengembalikan Variant — `:=` tidak bisa menyimpulkannya (Parse Error).
		var mirror: Dictionary = part.duplicate()
		mirror["pos"] = Vector3(part_pos.x,
			above - (part_pos.y - above) * squash, part_pos.z)
		mirror["size"] = Vector3(part_size.x, part_size.y * squash, part_size.z)
		reflection.add_child(_make_block(mirror, true))


func _make_block(part: Dictionary, faded: bool) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = part["size"]
	var material := StandardMaterial3D.new()
	if part["role"] == "glow":
		# Cahaya hangat dari celah pintu; emissive supaya ikut bloom.
		material.albedo_color = Color(1.0, 0.82, 0.52)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.78, 0.42)
		material.emission_energy_multiplier = 2.6 if not faded else 0.7
		material.roughness = 0.4
	elif part["role"] == "leaf":
		material.albedo_color = Color(0.13, 0.10, 0.08)
		material.roughness = 0.75
	else:
		material.albedo_color = Color(0.09, 0.075, 0.065)
		material.roughness = 0.85
	if faded:
		# Pantulan yang memudar: lebih terang sedikit (air menerima cahaya) tapi
		# transparan supaya tidak terlihat seperti pintu kedua.
		material.albedo_color = material.albedo_color.lerp(Color(0.35, 0.42, 0.5), 0.55)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color.a = 0.4
		material.emission_energy_multiplier *= 0.5
	var block := MeshInstance3D.new()
	block.name = str(part["role"])
	block.mesh = mesh
	block.material_override = material
	block.position = part["pos"]
	if faded:
		block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return block


## Ringkas untuk log dan tes.
func summary() -> String:
	var parts := door.get_child_count() if door != null else 0
	var mirror := reflection.get_child_count() if reflection != null else 0
	return "kolam r=%.0f m di y=%.2f, pintu %d bagian, pantulan %d bagian" % [
		WATER_RADIUS, Field.POND_LEVEL, parts, mirror]
