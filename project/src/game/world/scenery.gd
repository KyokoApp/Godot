extends Node3D
## Pemandangan di sekitar pulau 1 km, disusun supaya dunia terlihat seperti
## ilustrasi layar muat (`launcher/art/loading.jpg`): laut mengelilingi pulau,
## deretan bukit jauh di seberang air, tebing batu di timur, jalan tanah
## berliku, reruntuhan batu, dan titik cahaya melayang.
##
## Semuanya di LUAR garis pantai (atau di dalam pulau tapi tanpa collision)
## supaya gameplay, fisika, dan gerbang yang sudah ada tidak berubah: pemain
## tetap berjalan di pulau yang sama. Bentuknya prosedural (tanpa aset baru),
## jadi ringan untuk HP dan tidak menambah berkas biner.
##
## Susunannya sengaja mengikuti ilustrasi:
##   * laut  : mengelilingi SELURUH pulau (permukaan y = 0, garis pantai pulau)
##   * tebing: sisi +x, di seberang air, memanjang seperti dinding batu jauh
##   * bukit : dua cincin di luar garis pantai, terbaca sebagai daratan jauh
##   * jalan : tanah di pulau, berliku (lihat ground.gdshader)
##   * reruntuhan: dua gapura + tiga tiang di dekat jalan, di dalam pulau

const Field = preload("res://src/game/world/field.gd")
const WATER_SHADER = preload("res://src/game/world/water.gdshader")
const Dusk = preload("res://src/game/environment/dusk_environment.gd")

## Radius cincin bukit. HARUS di luar radius pulau maksimum (ISLAND_MAX 380 +
## dua lekukan pantai 30 = 410 m): kalau tidak, bukitnya tumbuh dari tengah
## pulau dan menutupi medan tempat pemain berjalan.
const HILL_RADIUS := 520.0
const HILL_REACH := 780.0
const FAR_RADIUS := 820.0
const FAR_REACH := 1250.0
## Laut: permukaan air sedikit di bawah nol (sedikit di bawah garis pantai pulau,
## yang memang berada di tinggi 0) supaya bidang air tidak z-fighting dengan
## tanah yang persis menyentuh y = 0. Bidangnya 4200 m — jauh melampaui bukit
## terjauh (1250 m) supaya ujungnya tidak terlihat sebelum ditutup kabut.
const SEA_LEVEL := -0.15
const SEA_SIZE := 4200.0
## Tinggi puncak bukit terdekat (di luar garis pantai) dan bukit jauh.
const HILL_HEIGHT := 26.0
const FAR_HEIGHT := 62.0
## Warnanya sama dengan ilustrasi: hijau pastel, batu biru keabuan, tanah hangat.
const HILL_COLOR := Color("6fae4f")
const HILL_LIGHT := Color("9ed37a")
const HILL_SHADE := Color("4c9a3d")
const ROCK_COLOR := Color("8fa6b8")
const ROCK_SHADE := Color("65808f")
const STONE_COLOR := Color("c8c3b4")
const MOSS_COLOR := Color("7fae63")
const DIRT_COLOR := Color("c9a873")
const MOTE_COLOR := Color("ffe9b0")

var hills: Node3D
var sea: MeshInstance3D
var ruins: Node3D
var motes: Node3D
var island: MeshInstance3D
var cliff_count := 0


func _ready() -> void:
	name = "Scenery"
	_build_sea()
	_build_island()
	_build_hills()
	_build_cliffs()
	_build_ruins()
	_build_motes()


# ------------------------------------------------------------------ laut ----

func _build_sea() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(SEA_SIZE, SEA_SIZE)
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
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
	# pulau) yang menutup sampai jauh di luar bukit puncak (± 2100 m).
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
	_add_rock_block(vertices, colors, indices, Vector3(-760.0, SEA_LEVEL - 12.0, 60.0),
		Vector3(90.0, 30.0, 44.0), 3)
	_add_rock_block(vertices, colors, indices, Vector3(-905.0, SEA_LEVEL - 14.0, 130.0),
		Vector3(60.0, 24.0, 32.0), 7)
	_commit(vertices, colors, indices, "Island", self)
	island = get_node("Island") as MeshInstance3D


# ----------------------------------------------------------------- bukit ----

func _build_hills() -> void:
	hills = Node3D.new()
	hills.name = "Hills"
	add_child(hills)
	# Cincin bukit terdekat: bergelombang mengelilingi pulau. Sengaja BERJAUHAN
	# dari garis pantai (radius 520 m, pulau maksimum ± 410 m) supaya tidak pernah
	# tumbuh di tanah tempat pemain berjalan. Celah di sisi barat membuat
	# siluetnya tidak seragam dari segala arah.
	_add_ridge(HILL_RADIUS, HILL_REACH, HILL_HEIGHT, 0.0, 96, 1.0)
	# Bukit jauh: lebih tinggi dan lebih pucat (kabut), menutup garis horizon.
	_add_ridge(FAR_RADIUS, FAR_REACH, FAR_HEIGHT, 0.45, 72, 0.55)


## Satu sabuk bukit: cincin vertex yang tingginya dari gelombang sinus, dengan
## warna yang makin pucat makin jauh (kabut) — sama seperti ilustrasi.
func _add_ridge(inner: float, outer: float, height: float, phase: float,
		segments: int, gap: float) -> void:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var sea_side := -PI * 0.5
	for index in range(segments + 1):
		var angle := TAU * float(index) / float(segments)
		var ridge := 0.55 + 0.45 * sin(angle * 3.0 + phase)
		ridge *= 0.6 + 0.4 * sin(angle * 7.0 - phase * 2.0)
		# Celah laut: sisi barat dibuat rendah/hilang.
		var openness := 1.0 - gap * exp(-pow(angle_difference(angle, sea_side) * 2.2, 2.0))
		var top := height * maxf(0.0, ridge) * openness
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var outer_point := direction * outer
		var inner_point := direction * inner
		vertices.append(Vector3(inner_point.x, -4.0, inner_point.z))
		colors.append(HILL_SHADE)
		vertices.append(Vector3(inner_point.x * 0.92, top * 0.45, inner_point.z * 0.92))
		colors.append(HILL_COLOR)
		vertices.append(Vector3(outer_point.x * 0.6 + inner_point.x * 0.4,
			top, outer_point.z * 0.6 + inner_point.z * 0.4))
		colors.append(HILL_LIGHT)
	for index in range(segments):
		var base := index * 3
		var next := (index + 1) * 3
		# Dua quad per segmen: lereng dalam dan punggung bukit.
		indices.append_array(PackedInt32Array([base, next, base + 1,
			next, next + 1, base + 1,
			base + 1, next + 1, base + 2,
			next + 1, next + 2, base + 2]))
	_commit(vertices, colors, indices, "Hills_%d" % segments, hills)


func angle_difference(a: float, b: float) -> float:
	var diff := fmod(a - b + PI, TAU)
	if diff < 0.0:
		diff += TAU
	return diff - PI


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
	# sebagai satu dinding batu, bukan deretan menara. Muka terdekat blok =
	# base_x - depth/2; depth maksimum 17 m dan garis pantai terjauh 368 m, jadi
	# base_x = Field.HALF + 13 menyisakan ± 130 m air di depannya.
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
	# Tiga titik: dua di sepanjang jalan, satu di dekat reruntuhan. Tingginya
	# DIHITUNG dari tanah pulau — dulu tanah rata ± 1 m sehingga y tetap masih
	# aman, sekarang dataran ± 6 m sehingga y tetap akan menenggelamkan motes.
	var spots: Array[Vector3] = [Vector3(-6.0, 1.4, -14.0), Vector3(-13.0, 1.6, -27.0),
		Vector3(4.0, 1.3, -8.0)]
	for spot in spots:
		var ground: float = Field.terrain_height(spot.x, spot.z)
		motes.add_child(_mote_emitter(spot + Vector3(0.0, ground, 0.0)))


func _mote_emitter(position: Vector3) -> GPUParticles3D:
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
	emitter.amount = 22
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
