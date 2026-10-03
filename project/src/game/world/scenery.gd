extends Node3D
## Pemandangan di sekitar pulau 100 m. Bukit tajam tiga segitiga sudah DIHAPUS
## (permintaan: "hapus itu pemandangan di depan ... kayak bantuk gunung tajam
## sama gelombang") dan diganti PULAU TERBANG: bongkahan batu rendah-poli yang
## melayang di seberang air, terbaca sebagai bentuk pipih bergaya ilustrasi tapi
## tetap terasa 3D karena miring dan berpindar naik-turun.
##
## Sisanya (laut, tebing, reruntuhan, titik cahaya) tetap seperti sebelumnya —
## semuanya di LUAR garis pantai atau tanpa collision, jadi gameplay, fisika,
## dan gerbang yang sudah ada tidak berubah.
##
## Susunannya:
##   * laut        : mengelilingi SELURUH pulau (permukaan y = 0)
##   * pulau terbang: enam bongkahan melayang jauh di seberang air
##   * tebing      : sisi +x, dinding batu jauh
##   * jalan       : tanah di pulau, berliku (lihat ground.gdshader)
##   * reruntuhan  : dua gapura + tiga tiang di dekat jalan, di dalam pulau
##   * partikel    : titik cahaya ungu melayang di atas jalan

const Field = preload("res://src/game/world/field.gd")
const WATER_SHADER = preload("res://src/game/world/water.gdshader")
const Dusk = preload("res://src/game/environment/dusk_environment.gd")

## Laut: permukaan air sedikit di bawah nol (sedikit di bawah garis pantai pulau,
## yang memang berada di tinggi 0) supaya bidang air tidak z-fighting dengan
## tanah yang persis menyentuh y = 0. Bidangnya 900 m — jauh melampaui pulau
## terbang terjauh supaya ujungnya tidak terlihat sebelum ditutup kabut.
const SEA_LEVEL := -0.15
const SEA_SIZE := 900.0
## Pulau terbang: setiap entri [jarak dari pusat, sudut, tinggi melayang, skala].
## Jaraknya jauh di luar garis pantai 100 m dan pulau batu supaya tetap menjadi
## latar, bukan menutupi jalan pemain. Kabut menjaga siluetnya tetap lembut.
const FLOATERS := [
	Vector4(150.0, -0.62, 22.0, 1.00),
	Vector4(186.0, 2.31, 30.0, 1.35),
	Vector4(213.0, 1.12, 18.0, 0.80),
	Vector4(238.0, 3.66, 36.0, 1.60),
	Vector4(265.0, -2.72, 27.0, 1.10),
	Vector4(288.0, 0.35, 40.0, 1.45),
]
## Amplitudo & kecepatan mengapung (detik satu siklus) — bergoyang pelan saja,
## ini latar belakang, jangan sampai menarik perhatian dari pemain.
const FLOAT_BOB := 1.6
const FLOAT_PERIOD := 7.0
## Warna pulau terbang: tanah cokelat, rumput hijau, batu kebiruan.
const FLOAT_GRASS := Color("6fae4f")
const FLOAT_GRASS_LIGHT := Color("9ed37a")
const FLOAT_ROCK := Color("7d8fa0")
const FLOAT_ROCK_DARK := Color("55697a")
## Warnanya sama dengan ilustrasi: hijau pastel, batu biru keabuan, tanah hangat.
const ROCK_COLOR := Color("8fa6b8")
const ROCK_SHADE := Color("65808f")
const STONE_COLOR := Color("c8c3b4")
const MOSS_COLOR := Color("7fae63")
const DIRT_COLOR := Color("9a8260")
## Titik cahaya melayang: UNGU (permintaan "partikel ungu"), bukan krem lagi.
## Sebelumnya ini satu-satunya partikel berwarna hangat — efek lain (jejak api
## kaki, aura kecepatan, roh, serangan) sudah ungu semua.
const MOTE_COLOR := Color("c9a6ff")

var sea: MeshInstance3D
var floaters: Node3D
var ruins: Node3D
var motes: Node3D
var island: MeshInstance3D
var cliff_count := 0
var _floaters: Array[Node3D]
var _time: float


func _ready() -> void:
	name = "Scenery"
	_build_sea()
	_build_island()
	_build_floaters()
	_build_cliffs()
	_build_ruins()
	_build_motes()


# ------------------------------------------------------------------ laut ----

func _build_sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(SEA_SIZE, SEA_SIZE)
	# Sel air ± 7 m (128 x 128 = 33 ribu segitiga). Ini yang membuat gelombang
	# MUNCUL di dekat pemain: air.gdshader menghitung riaknya per piksel, tapi
	# permukaannya sendiri tetap digerakkan di vertex, dan 24 sel (37 m) dulu
	# terlalu kasar untuk terlihat.
	plane.subdivide_width = 128
	plane.subdivide_depth = 128
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	# Kilau di air harus searah dengan matahari senja, bukan arah bawaan shader.
	material.set_shader_parameter("sun_direction", Dusk.SUN_DIRECTION)
	sea = MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = plane
	sea.material_override = material
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Laut mengelilingi SELURUH pulau: satu bidang besar di y = 0 (garis pantai
	# pulau) yang menutup sampai jauh di luar pulau terbang terjauh (± 300 m).
	sea.position = Vector3(0.0, SEA_LEVEL, 0.0)
	add_child(sea)


## Pulau kecil di seberang laut, seperti di ilustrasi: sisi batu dengan puncak
## hijau. Dasarnya jauh di bawah permukaan laut supaya tidak terlihat sebagai
## balok. Tidak ada collision — hanya latar.
func _build_island() -> void:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	# Dua blok: yang utama panjang dan rendah, yang kedua lebih kecil di
	# belakangnya supaya siluetnya tidak terlihat seperti satu balok.
	_add_rock_block(vertices, colors, indices, Vector3(-147.0, SEA_LEVEL - 12.0, 0.0),
		Vector3(9.0, 16.0, 4.5), 3)
	_add_rock_block(vertices, colors, indices, Vector3(-159.0, SEA_LEVEL - 14.0, 2.0),
		Vector3(6.0, 15.0, 3.5), 7)
	_commit(vertices, colors, indices, "Island", self)
	island = get_node("Island") as MeshInstance3D


# ------------------------------------------------- pulau terbang (2D→3D) ----


## Pulau-pulau kecil yang melayang di seberang air: bongkahan batu yang puncaknya
## ditutupi rumput, bagian bawah meruncing ke satu titik. Bentuk pipih + warna
## rata bikin terbaca seperti gambar 2D, tapi karena miring, berbayang, dan
## mengapung naik-turun, tetap terasa sebagai objek 3D.
func _build_floaters() -> void:
	floaters = Node3D.new()
	floaters.name = "Floaters"
	add_child(floaters)
	for entry: Vector4 in FLOATERS:
		# Tipe harus ditulis eksplisit: `entry` dari Array tak bertipe adalah
		# Variant, dan `:=` tidak bisa menyimpulkan tipe darinya (Parse Error).
		var distance: float = entry.x
		var angle: float = entry.y
		var height: float = entry.z
		var scale: float = entry.w
		var holder := Node3D.new()
		holder.position = Vector3(cos(angle) * distance, height, sin(angle) * distance)
		holder.rotation.y = angle + PI * 0.5
		# Miring sedikit: satu sisi lebih tinggi, jadi siluetnya tidak simetris
		# (siluet simetris justru terbaca sebagai gambar 2D).
		holder.rotation.z = sin(angle * 2.3) * 0.09
		var mesh := _floater_mesh(11.0 * scale, 15.0 * scale)
		var block := MeshInstance3D.new()
		block.mesh = mesh
		block.name = "Floater"
		floaters.add_child(holder)
		holder.add_child(block)
		# Rumput/partikel kecil di puncak biar puncaknya tidak kosong melompong.
		var motes := _mote_emitter(Vector3(0.0, 2.2 * scale, 0.0), 3)
		holder.add_child(motes)
		_floaters.append(holder)


## Satu bongkahan pulau terbang: cakram rumput di puncak, lalu kerucut batu yang
## meruncing ke satu titik di bawah. Setiap segitiga memakai satu warna rata,
## jadi bidangnya terbaca datar seperti ilustrasi.
func _floater_mesh(radius: float, depth: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var segments := 10
	# Jari-jari puncak (rumput). Sisanya kerucut batu yang meruncing ke bawah.
	var rim := radius * 0.55
	# --- puncak rumput: cakram diisi segitiga dari pusat ---
	var centre := vertices.size()
	vertices.append(Vector3.ZERO)
	colors.append(FLOAT_GRASS)
	var ring: Array[Vector3] = []
	for step in range(segments):
		var a := TAU * float(step) / float(segments)
		# Gobangan kecil supaya siluetnya tidak bulat sempurna — lingkaran
		# sempurna justru terbaca sebagai gambar 2D.
		var wobble := 1.0 + 0.09 * sin(a * 3.0) + 0.05 * cos(a * 5.0)
		var edge := Vector3(cos(a) * rim * wobble, 0.0, sin(a) * rim * wobble)
		ring.append(edge)
		vertices.append(edge)
		colors.append(FLOAT_GRASS_LIGHT if step % 2 == 0 else FLOAT_GRASS)
	for step in range(segments):
		# Urutan (centre, next, here): normalnya menghadap ATAS. Dibalik, seluruh
		# puncak rumput tidak terlihat sama sekali (cull_back).
		indices.append(centre)
		indices.append(centre + 1 + (step + 1) % segments)
		indices.append(centre + 1 + step)
	# --- kerucut batu: dari tepi puncak turun ke satu titik terbawah ---
	var tip := vertices.size()
	vertices.append(Vector3(0.0, -depth, 0.0))
	colors.append(FLOAT_ROCK_DARK)
	for step in range(segments):
		var here := centre + 1 + step
		var next := centre + 1 + (step + 1) % segments
		# Urutan (here, next, tip): normalnya menghadap KELUAR. Kalau terbalik,
		# seluruh bongkahan jadi tidak terlihat (cull_back).
		indices.append(here)
		indices.append(next)
		indices.append(tip)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _process(delta: float) -> void:
	# Mengapung pelan; `_time` juga dipakai partikel supaya keduanya selaras.
	_time += delta
	for index in range(_floaters.size()):
		var holder := _floaters[index] as Node3D
		var entry: Vector4 = FLOATERS[index]
		if holder == null:
			continue
		holder.position.y = entry.z + FLOAT_BOB * sin(
			_time * TAU / FLOAT_PERIOD + float(index) * 1.7)


# ---------------------------------------------------------------- tebing -----

func _build_cliffs() -> void:
	# Dinding batu di sisi +x (timur), di SEBERANG air (tepat di luar garis
	# pantai), memanjang seperti di ilustrasi; dibelah beberapa blok supaya
	# terlihat seperti formasi batu.
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var blocks := 9
	# Blok dibuat saling menimpa (lebar 15 m, jarak titik 12,5 m) supaya terbaca
	# sebagai satu dinding batu. Muka terdekat blok sekitar x=54 m, di luar garis
	# pantai pulau 100 m, sehingga tetap menjadi latar tanpa collision.
	var base_x := Field.HALF + 13.0
	for block in range(blocks):
		var center_z := -Field.HALF + 12.0 + float(block) * 12.5
		var height := 17.0 + 4.0 * sin(float(block) * 1.7)
		var depth := 14.0 + 3.0 * cos(float(block) * 2.3)
		var offset := 1.6 * sin(float(block) * 2.1)
		_add_rock_block(vertices, colors, indices,
			Vector3(base_x + offset, -3.0, center_z),
			Vector3(depth, height, 15.0), block)
	cliff_count = blocks
	_commit(vertices, colors, indices, "Cliffs", self)


## Satu blok batu: piramida terpancung dengan sisi miring, warna batu + lumut di
## puncaknya (seperti tanaman rambat di ilustrasi).
func _add_rock_block(vertices: PackedVector3Array, colors: PackedColorArray,
		indices: PackedInt32Array, base: Vector3, size: Vector3, seed: int) -> void:
	var wobble := sin(float(seed) * 3.1) * 0.35
	# Array bertipe: tanpa tipe, Godot tidak bisa menyimpulkan tipe variabel yang
	# diambil darinya (error "Cannot infer the type of inner_next").
	var corners: Array[Vector3] = [
		Vector3(-0.5, 0.0, -0.5), Vector3(0.5, 0.0, -0.5),
		Vector3(0.5, 0.0, 0.5), Vector3(-0.5, 0.0, 0.5)]
	var start := vertices.size()
	for corner in corners:
		vertices.append(base + Vector3(corner.x * size.x, 0.0, corner.z * size.z))
		colors.append(ROCK_SHADE)
	for index in range(4):
		var next := (index + 1) % 4
		var inner := corners[index] * 0.55 + Vector3(wobble, 0.0, -wobble)
		var inner_next := corners[next] * 0.55 + Vector3(wobble, 0.0, -wobble)
		vertices.append(base + Vector3(inner.x * size.x, size.y * 0.72, inner.z * size.z))
		colors.append(ROCK_COLOR)
		vertices.append(base + Vector3(inner_next.x * size.x, size.y * 0.72,
			inner_next.z * size.z))
		colors.append(ROCK_COLOR)
		var top := start + 4 + index * 2
		indices.append_array(PackedInt32Array([start + index, start + next, top,
			start + next, top + 1, top]))
	# Atap: empat segitiga dari puncak yang sama (dengan lumut di tengahnya).
	var cap := vertices.size()
	vertices.append(base + Vector3(wobble * size.x, size.y, wobble * size.z))
	colors.append(MOSS_COLOR)
	for index in range(4):
		var top := start + 4 + index * 2
		indices.append_array(PackedInt32Array([top, top + 1, cap]))


# ------------------------------------------------------------- reruntuhan ----

func _build_ruins() -> void:
	ruins = Node3D.new()
	ruins.name = "Ruins"
	add_child(ruins)
	# Dua gapura batu di sisi barat laut jalan, seperti di ilustrasi, plus tiga
	# tiang yang miring karena sudah lapuk.
	_add_arch(Vector3(-14.0, 0.0, -18.0), 0.35)
	_add_arch(Vector3(-9.0, 0.0, -30.0), -0.2)
	_add_pillar(Vector3(-19.0, 0.0, -26.0), 2.6, 0.20)
	_add_pillar(Vector3(-11.5, 0.0, -24.5), 2.1, -0.35)
	_add_pillar(Vector3(-17.0, 0.0, -31.0), 1.5, 0.5)


## Gapura: dua tiang + balok atas, dengan lumut di sisi atasnya.
func _add_arch(origin: Vector3, tilt: float) -> void:
	var ground := Field.terrain_height(origin.x, origin.z)
	var basis := Basis(Vector3.FORWARD, tilt)
	ruins.add_child(_stone_block(basis, origin + Vector3(0.0, ground + 1.5, 0.0),
		Vector3(0.7, 3.0, 0.7)))
	ruins.add_child(_stone_block(basis, origin + Vector3(3.2, ground + 1.5, 0.0),
		Vector3(0.7, 3.0, 0.7)))
	ruins.add_child(_stone_block(basis, origin + Vector3(1.6, ground + 3.15, 0.0),
		Vector3(4.6, 0.55, 0.8)))


func _add_pillar(origin: Vector3, height: float, lean: float) -> void:
	var ground := Field.terrain_height(origin.x, origin.z)
	var basis := Basis(Vector3.FORWARD, lean).scaled(Vector3.ONE)
	ruins.add_child(_stone_block(basis, origin + Vector3(0.0, ground + height * 0.5, 0.0),
		Vector3(0.62, height, 0.62)))


func _stone_block(basis: Basis, position: Vector3, size: Vector3) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = STONE_COLOR
	material.roughness = 0.9
	# Lumut di permukaan atas: warna puncak saja, murah dan tidak perlu shader.
	material.vertex_color_use_as_albedo = true
	var instance := MeshInstance3D.new()
	instance.mesh = box
	instance.material_override = material
	instance.transform = Transform3D(basis, position)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return instance


# -------------------------------------------------- titik cahaya melayang ----

func _build_motes() -> void:
	motes = Node3D.new()
	motes.name = "LightMotes"
	add_child(motes)
	# Titik cahaya menyebar di sepanjang jalan skala pulau 100 m. Tingginya
	# tetap dihitung dari terrain supaya partikel mengikuti bukit.
	var spots: Array[Vector3] = [Vector3(-18.0, 1.4, -8.0), Vector3(-23.0, 1.6, -16.0),
		Vector3(19.0, 1.3, -5.0)]
	for step in range(-4, 5):
		var along := step * 6.0
		# Geser 3 m ke samping jalan supaya partikel melayang di atas rumput.
		spots.append(Vector3(along, 1.4, _path_centre(along) + 3.0))
	for spot in spots:
		var ground: float = Field.terrain_height(spot.x, spot.z)
		motes.add_child(_mote_emitter(spot + Vector3(0.0, ground, 0.0)))


## Garis tengah yang sama dengan shader tanah dan aturan pertumbuhan rumput.
func _path_centre(x: float) -> float:
	return Field.path_centre(x)


func _mote_emitter(position: Vector3, amount: int = 22) -> GPUParticles3D:
	var material := ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(3.5, 1.2, 3.5)
	material.direction = Vector3(0.0, 1.0, 0.0)
	material.spread = 25.0
	material.initial_velocity_min = 0.05
	material.initial_velocity_max = 0.22
	material.gravity = Vector3(0.0, 0.02, 0.0)
	material.scale_min = 0.35
	material.scale_max = 0.9
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.08, 0.08)
	# Bahan tanpa cahaya: titik ini memang sumber cahaya kecil di ilustrasi.
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = MOTE_COLOR
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow.disable_receive_shadows = true
	var emitter := GPUParticles3D.new()
	emitter.name = "Motes"
	emitter.amount = amount
	emitter.lifetime = 6.0
	emitter.preprocess = 4.0
	emitter.explosiveness = 0.0
	emitter.process_material = material
	emitter.draw_pass_1 = mesh
	emitter.material_override = glow
	emitter.position = position
	emitter.visibility_aabb = AABB(Vector3(-8.0, -3.0, -8.0), Vector3(16.0, 8.0, 16.0))
	return emitter


# ---------------------------------------------------------------- bantuan ----

func _commit(vertices: PackedVector3Array, colors: PackedColorArray,
		indices: PackedInt32Array, mesh_name: String, parent: Node3D) -> void:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var visual := MeshInstance3D.new()
	visual.name = mesh_name
	visual.mesh = mesh
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
