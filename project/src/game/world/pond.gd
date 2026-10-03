extends Node3D
## DANAU tengah pulau (bukan kolam dalam): air cetek bergelombang menggenang di
## sekitar sebuah pintu yang berdiri di tengah, di ATAS permukaan air
## (referensi anime Suzume). Semuanya prosedural — tidak ada aset baru.
##
## Yang membuatnya danau dan bukan kolam:
##   1. airnya cuma 0,45 m — dasarnya jelas terlihat, bukan genangan pekat,
##   2. pintunya berdiri di puncak pulau batu kecil, jadi kakinya tidak
##      pernah tenggelam,
##   3. permukaan air BISA DIAKI: ada cakram tabrakan tak terlihat setinggi
##      garis air, jadi pemain berjalan DI ATAS air dan setiap langkah
##      meninggalkan riak (lihat water_ripple.gd).
##
## Air memakai water.gdshader yang SAMA dengan laut, hanya parameter gelombang
## dan warnanya yang lebih tenang. Pintunya punya "pantulan" tiruan: salinan
## terbalik di bawah permukaan air, karena renderer Mobile tidak punya SSR
## (screen-space reflection hanya ada di Forward+).

const Field = preload("res://src/game/world/field.gd")
const WATER_SHADER = preload("res://src/game/world/water.gdshader")
const Dusk = preload("res://src/game/environment/dusk_environment.gd")

## Jari-jari bidang air (meter) = POND_RADIUS di field.gd. Dengan cekungan
## cetek (dasar 3,85 m naik 1,15 m sampai dataran 5 m dalam 20 m), tanah
## melintasi POND_LEVEL tepat di 23,8 m — jadi bidang air 23,5 m pas menutupi
## danau tanpa menjorok ke daratan kering.
const WATER_RADIUS := 23.5
## Cincin dan juring mesh air: 24 x 64 = 3 ribu segitiga, cukup halus untuk
## gelombang yang terlihat di danau selebar 47 m.
const RINGS := 24
const SEGMENTS := 64
## Ukuran pintu (meter).
const DOOR_HEIGHT := 3.8
const DOOR_WIDTH := 1.9
## Pulau batu kecil di tengah danau: pintunya berdiri DI ATAS batu ini, jadi
## dasar pintu tidak pernah tenggelam di air. Puncaknya 0,5 m di atas garis air
## dan lerengnya landai sampai menyentuh air, jadi pemain tetap bisa naik.
const PLATFORM_TOP := 0.5
const PLATFORM_FLAT := 2.8
const PLATFORM_OUTER := 5.2

var water: MeshInstance3D
var platform: MeshInstance3D
var door: Node3D
var reflection: Node3D


func _ready() -> void:
	name = "Pond"
	_build_water()
	_build_platform()
	_build_door()


# ------------------------------------------------------------------- air ----

func _build_water() -> void:
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("sun_direction", Dusk.SUN_DIRECTION)
	# Danau tenang: gelombang lebih pendek dan lebih pendek tingginya dari laut.
	material.set_shader_parameter("wave_height", 0.04)
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


# ------------------------------------------------- pulau batu & pijakan ----

## Pulau batu di tengah danau (kerucut pendek). Pintunya berdiri di puncak yang
## rata, lerengnya turun sampai menyentuh garis air — bentuk inilah yang membuat
## pintu terbaca "berdiri di tengah danau" tapi TIDAK tenggelam.
func _build_platform() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = PLATFORM_FLAT
	mesh.bottom_radius = PLATFORM_OUTER
	# Sengaja dimasukkan ke bawah garis air supaya tidak ada garis pertemuan
	# yang berkedip tepat di permukaan air.
	mesh.height = PLATFORM_TOP + 0.06
	mesh.radial_segments = 48
	mesh.rings = 4
	var material := StandardMaterial3D.new()
	# Batu basah: gelap, sedikit kehijauan seperti lumutan di garis air.
	material.albedo_color = Color(0.15, 0.17, 0.17)
	material.roughness = 0.92
	platform = MeshInstance3D.new()
	platform.name = "Platform"
	platform.mesh = mesh
	platform.material_override = material
	platform.position = Vector3(0.0, Field.POND_LEVEL - 0.06, 0.0)
	platform.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(platform)
	# Tanpa collider, pemain tertahan di dinding batu dan tidak bisa naik ke
	# pintu — lerengnya harus bisa didaki seperti tanah biasa.
	var body := StaticBody3D.new()
	body.name = "PlatformBody"
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	body.position = platform.position
	add_child(body)


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
	# Pintunya berdiri di PUNCAK pulau batu, bukan di dasar kolam: kakinya
	# selalu di ATAS permukaan air danau, persis yang diminta pemain.
	var base := Field.POND_LEVEL + PLATFORM_TOP

	door = Node3D.new()
	door.name = "Door"
	door.position = Vector3(0.0, base, 0.0)
	add_child(door)
	for part: Dictionary in _door_parts():
		door.add_child(_make_block(part, false))
	# Pantulan tiruan: salinan terbalik di bawah permukaan air. Air danau
	# sekarang cuma setengah meter dalam, jadi pantulan setinggi aslinya akan
	# terkubur tanah — karena itu tingginya DIPENAMPAS (squash) supaya tetap
	# terbaca di antara dasar kolam dan permukaan air, persis seperti
	# pantulan benda tinggi di air cetek.
	var above := Field.POND_LEVEL - floor_height
	# Bagian tertinggi pintu (diukur dari dasar kolam) menentukan seberapa
	# kuat pantulan harus dipenampas: makin cetek air, makin tipis pantulan.
	var top := 0.0
	for part: Dictionary in _door_parts():
		var part_pos: Vector3 = part["pos"]
		var part_size: Vector3 = part["size"]
		top = maxf(top, part_pos.y + part_size.y * 0.5)
	var squash := clampf(above / maxf(top + PLATFORM_TOP, 0.1), 0.05, 0.35)
	reflection = Node3D.new()
	reflection.name = "DoorReflection"
	reflection.position = Vector3(0.0, floor_height, 0.0)
	add_child(reflection)
	for part: Dictionary in _door_parts():
		var part_pos: Vector3 = part["pos"]
		var part_size: Vector3 = part["size"]
		# Tinggi pantulan diukur dari DASAR kolam: permukaan air di `above`,
		# lalu jarak bagian itu di atas garis air dipenampas oleh squash.
		var mirror_y := above - (PLATFORM_TOP + part_pos.y) * squash
		# Bagian yang pantulannya sudah lewat dasar kolam tidak dipantulkan.
		if mirror_y + part_size.y * squash * 0.5 <= 0.0:
			continue
		# Tipe harus eksplisit: `part` bertipe Dictionary, tapi `duplicate()`
		# mengembalikan Variant — `:=` tidak bisa menyimpulkannya (Parse Error).
		var mirror: Dictionary = part.duplicate()
		mirror["pos"] = Vector3(part_pos.x, mirror_y, part_pos.z)
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
	return ("danau r=%.0f m di y=%.2f (dalam %.2f m), batu tengah %.1f m di "
		+ "atas air, pintu %d bagian, pantulan %d bagian, pijakan air collider terrain") % [
		WATER_RADIUS, Field.POND_LEVEL,
		Field.POND_LEVEL - Field.terrain_height(0.0, 0.0), PLATFORM_TOP,
		parts, mirror]
