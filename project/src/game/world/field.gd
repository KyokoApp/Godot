extends Node3D
## Pulau 300 m × 300 m: dataran bergelombang dengan garis pantai tidak beraturan
## (bukan bulat, bukan kotak), dikelilingi laut di permukaan y = 0. Semua panjang
## (radius pulau, lekukan pantai, tanjakan pantai, jalan) diskalakan dari 100 m.
##
## Satu fungsi tinggi (`terrain_height`) dipakai oleh SEMUA: mesh, collider,
## karakter, rumput, tapak api, dan langkah kaki. Itu sebabnya fungsi ini statis
## dan murni — tidak boleh bergantung pada node, frame, atau urutan build.
##
## Kenapa chunk streaming (bukan satu mesh 300 m): medan 300 m pada sel 2 m =
## ~22 ribu sel — streaming tetap dipakai. Chunk 32 m × 32 m (16 × 16 sel)
## dibangun SATU per frame mengelilingi pemain; jangkauan 5 berarti 11 × 11 =
## 121 chunk (± 352 m), cukup menutup seluruh pulau 300 m dari mana pun pemain
## berdiri. Chunk yang seluruhnya di laut tidak pernah dibangun.

const SHADER = preload("res://src/game/ground.gdshader")
const MEADOW = preload("res://assets/nature/meadow_cover.png")
const SIZE := 300.0
const HALF := SIZE * 0.5

## Chunk 32 m, sel 2 m (16 × 16 sel, 17 × 17 titik) agar bukit halus.
const CHUNK := 32.0
const CHUNK_CELLS := 16
const SIDE := CHUNK_CELLS + 1
const CELL := CHUNK / float(CHUNK_CELLS)
## Radius chunk yang dipegang: 5 -> 11 × 11 = 121 chunk = 352 m × 352 m.
const CHUNK_RADIUS := 5
const WALK_MARGIN := 0.7

## Bentuk pulau — diskalakan 3× dari 100 m (29/38 -> 87/114).
const ISLAND_MIN := 87.0
const ISLAND_MAX := 114.0
## Lekukan halus garis pantai (meter) — skala 3× biar proporsi tetap cozy.
const COAST_WAVE := 9.0
const COAST_WAVE_B := 4.5
## Dasar laut dan tinggi dataran pulau (meter di atas permukaan air). Dataran
## harus DI ATAS pita pasir shader (2,6 m), kalau tidak seluruh pulau berbunyi
## tanah dan bukan rumput. 3 m / 12 m = 0,25 < 0,30 (MAX_SLOPE), jadi rumput
## tetap tumbuh di tanjakan pantai.
const SEA_FLOOR := -3.0
const PLATEAU := 3.0
## Tanjakan dari garis air ke dataran (meter). 3 m / 12 m ≈ 25% — masih bisa
## dilalui dan terbaca sebagai pantai curam, bukan ramp panjang.
const BEACH_RUN := 12.0
## Kemiringan maksimum supaya rumput/akar tidak melayang di lereng.
const MAX_SLOPE := 0.30
## Rumput butuh tanah kering: minimal setinggi ini di atas air.
const GRASS_MIN_HEIGHT := 0.55
## Jarak minimum rumput dari garis pantai (meter) supaya pasir tetap polos.
const GRASS_SHORE_MARGIN := 2.5

## Palet senja: hijau tua yang MASIH terbaca (bukan hitam). Permintaan pengguna:
## "tanah dan rumput jadi gelap tapi tetap kelihatan, dan rumput satu warna dengan
## tanah". Angkanya ± 45% dari hijau muda lama (8fce63) supaya di bawah cahaya
## senja hasilnya tetap di atas 0,22 kanal hijau — batas gerbang test_dusk.
const GRASS_COLOR := Color("3f6b34")
const GRASS_DARK := Color("2d4f27")
## Pasir juga meredup: senja bukan siang. ± 25% dari c9a873.
const SAND_COLOR := Color("9a8260")
# Jalan tanah berliku (digambar shader, tanpa mesh/collision tambahan).
const PATH_WIDTH := 1.2
## Lekuk 4,8 m dengan panjang gelombang ± 60 m: jalan berliku ± 5 kali sepanjang
## pulau 300 m dan kemiringannya tetap di bawah 37°. Aturannya: hasil kali
## lekuk × frekuensi harus di bawah 0,75, kalau tidak jalannya terbelok tajam
## (terbaca garis diagonal, bukan jalan) — itu yang terjadi dulu.
const PATH_CURVE := 4.8
const PATH_FREQUENCY := 0.105
## Lekukan kedua: lebih pendek dan amplitudo lebih kecil supaya jalannya tidak
## terlihat seperti satu sinus raksasa.
const PATH_FREQUENCY_B := 0.165
const PATH_PHASE_B := 1.33
## Jarak minimum rumput dari garis tengah jalan tanah. Shader tanah menggambar
## jalan selebar ± 1,25x PATH_WIDTH (plus noise tepi ± 0,55 m), jadi 1 m sudah
## lebih dari cukup. Tanpa batas ini rumput tumbuh tepat di atas jalan dan pas
## pemain mendekat, jalan terlihat "hilang" ditelan rumput.
const GRASS_PATH_MARGIN := 1.0
# Pulau polos tanpa rumput (request user) — matikan spawn rumput sepenuhnya
const DISABLE_GRASS := true

## Tabel radius pulau per sudut (dihitung sekali): tanpa ini setiap pemeriksaan
## "di dalam pulau?" harus menghitung noise, dan rumput memanggilnya 11 ribu
## kali per tile.
static var _radius_table := PackedFloat32Array()

## Pemain (dipakai streaming chunk); boleh null saat diuji.
var player: Node3D
var _material: ShaderMaterial
var _grass_cover := true
## Tinggi tiap chunk yang sudah dihitung: kunci Vector2i(cx, cz) -> grid SIDE×SIDE.
var _heights: Dictionary = {}
## Node mesh + collider tiap chunk yang sedang ada di pohon.
var _chunks: Dictionary = {}
var _pending: Array[Vector2i] = []
var _center := Vector2i(99999, 99999)


func _ready() -> void:
	name = "Field"
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("meadow_cover", MEADOW)
	_material.set_shader_parameter("grass_color", GRASS_COLOR)
	_material.set_shader_parameter("grass_dark", GRASS_DARK)
	_material.set_shader_parameter("sand_color", SAND_COLOR)
	_material.set_shader_parameter("path_color", SAND_COLOR)
	_material.set_shader_parameter("path_width", PATH_WIDTH)
	_material.set_shader_parameter("path_curve", PATH_CURVE)
	_material.set_shader_parameter("path_frequency", PATH_FREQUENCY)
	_material.set_shader_parameter("path_enabled", true)
	# Chunk di titik muncul dibangun SEKARANG (bukan satu per frame): pemain
	# harus punya lantai sebelum frame fisika pertama, kalau tidak ia jatuh
	# menembus dunia sebelum chunk streaming semapat membangun.
	var center := _chunk_key(0.0, 0.0)
	_build_chunk(center)
	_recenter(center)
	# Pulau 300 m: SELURUH chunk tanah dibangun sekali di awal. Dengan
	# streaming satu-per-frame, rumput (dan jejak kaki, dan tapak api) bisa
	# dibangun SEBELUM chunk-nya ada lalu memakai fungsi analitik; beberapa
	# sentimeter kemudian chunk-nya muncul dan tingginya bergeser — itu yang
	# membuat akar rumput terbaca "mengambang". Sekarang grid selalu siap.
	_build_everything()


## Bangun semua chunk yang mengandung daratan. Jumlahnya terbatas (pulau 300 m
## ≈ 121 chunk), jadi ini murah dan hanya terjadi sekali.
func _build_everything() -> void:
	var reach := CHUNK_RADIUS + 2
	for cz in range(-reach, reach + 1):
		for cx in range(-reach, reach + 1):
			var key := Vector2i(cx, cz)
			if not _chunks.has(key) and _chunk_has_land(key):
				_build_chunk(key)


func _process(_delta: float) -> void:
	if _pending.is_empty():
		return
	# Satu chunk per frame: membangun chunk = 1.089 titik tinggi + collider,
	# kalau dilakukan sekaligus akan muncul hitch yang terasa di HP.
	_build_chunk(_pending.pop_front())


# ------------------------------------------------------------- bentuk pulau ----

## Radius pulau pada sudut tertentu (meter). Murni dari sudut, jadi pulau ini
## selalu "bintang" (setiap arah dari pusat hanya memotong pantai sekali) —
## itu yang membuat `clamp_inside` bisa bekerja dengan proyeksi radial.
static func island_radius(angle: float) -> float:
	if _radius_table.is_empty():
		_build_radius_table()
	var steps := _radius_table.size()
	var t := fposmod(angle, TAU) / TAU * float(steps)
	var index := int(t) % steps
	# floorf(), bukan floor(): fungsi global floor() mengembalikan Variant dan
	# `:=` dari Varian adalah COMPILE ERROR di Godot 4.5.
	var blend: float = t - floorf(t)
	var near := _radius_table[index]
	var far := _radius_table[(index + 1) % steps]
	return lerpf(near, far, blend)


static func _build_radius_table() -> void:
	const STEPS := 1024
	_radius_table.resize(STEPS)
	for step in range(STEPS):
		var angle := TAU * float(step) / float(STEPS)
		# Noise rendah di sepanjang lingkaran: garis pantai tidak berulang
		# seperti pola sinus, jadi terbaca sebagai pulau sungguhan.
		var n := _fbm(cos(angle) * 1.85 + 7.31, sin(angle) * 1.85 + 3.17)
		var radius := lerpf(ISLAND_MIN, ISLAND_MAX, n)
		radius += COAST_WAVE * sin(angle * 6.0 + 0.9)
		radius += COAST_WAVE_B * sin(angle * 11.0 - 2.2)
		_radius_table[step] = radius


## Tinggi tanah pada (x, z). Nol persis di garis pantai, negatif di laut.
static func terrain_height(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var radial := point.length()
	var angle := point.angle()
	var coast := island_radius(angle)
	var inland := coast - radial
	# Dataran: datar di pedalaman, tanjakan landai menuju air.
	var profile: float
	if inland >= BEACH_RUN:
		profile = PLATEAU
	elif inland > 0.0:
		profile = PLATEAU * (inland / BEACH_RUN)
	else:
		# Dasar laut terus turun supaya pantai tidak terlihat seperti potongan.
		profile = maxf(SEA_FLOOR, inland * 0.085)
	# Bukit jelas di pedalaman lalu melembut ke pantai supaya garis air tetap
	# bersih. Fade halus menghindari perubahan kemiringan yang mendadak.
	var fade := clampf(inland / 12.0, 0.0, 1.0)
	fade = fade * fade * (3.0 - 2.0 * fade)
	var hills := _rolling(x, z) * 2.2 * fade
	return profile + hills


## Bukit lebar, punggung diagonal, dan gelombang pendek bercampur agar medan
## terbaca berundulasi, bukan bidang datar dengan satu sinus berulang.
static func _rolling(x: float, z: float) -> float:
	var v := 0.85 * sin(x * 0.055 + 1.3) * cos(z * 0.046 - 0.4)
	v += 0.58 * sin((x + z) * 0.095 + 2.1)
	v += 0.30 * sin(x * 0.16 - 1.1) * cos(z * 0.13 + 0.7)
	return clampf(v * 0.8, -1.0, 1.0)


static func _hash(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263) & 0xFFFFFFFF
	n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
	n = (n ^ (n >> 16)) & 0xFFFFFFFF
	return float(n) / 4294967295.0


static func _noise(x: float, y: float) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var xf := x - float(xi)
	var yf := y - float(yi)
	var u := xf * xf * (3.0 - 2.0 * xf)
	var v := yf * yf * (3.0 - 2.0 * yf)
	var a := _hash(xi, yi)
	var b := _hash(xi + 1, yi)
	var c := _hash(xi, yi + 1)
	var d := _hash(xi + 1, yi + 1)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)


static func _fbm(x: float, y: float) -> float:
	var sum := 0.0
	var amp := 0.5
	var fx := x
	var fy := y
	for _octave in range(4):
		sum += _noise(fx, fy) * amp
		fx *= 2.03
		fy *= 2.01
		amp *= 0.5
	return sum / 0.9375


# ----------------------------------------------------------- fungsi bersama ----

## Interpolasi segitiga dari grid chunk — SAMA dengan collider, bukan perkiraan.
## Kalau chunk belum pernah dihitung, jatuh ke fungsi analitik (hasilnya hanya
## beda beberapa milimeter dari grid).
func surface_height(x: float, z: float) -> float:
	var key := _chunk_key(x, z)
	if not _heights.has(key):
		return terrain_height(x, z)
	var grid: PackedFloat32Array = _heights[key]
	var origin := _chunk_origin(key)
	var lx := (x - origin.x) / CELL
	var lz := (z - origin.y) / CELL
	var ix := clampi(int(floor(lx)), 0, CHUNK_CELLS - 1)
	var iz := clampi(int(floor(lz)), 0, CHUNK_CELLS - 1)
	var fx := clampf(lx - float(ix), 0.0, 1.0)
	var fz := clampf(lz - float(iz), 0.0, 1.0)
	var a: float = grid[iz * SIDE + ix]
	var b: float = grid[iz * SIDE + ix + 1]
	var c: float = grid[(iz + 1) * SIDE + ix]
	var d: float = grid[(iz + 1) * SIDE + ix + 1]
	if fx + fz <= 1.0:
		return a + (b - a) * fx + (c - a) * fz
	return d + (c - d) * (1.0 - fx) + (b - d) * (1.0 - fz)


## Titik dianggap di dalam pulau kalau berjarak minimal `margin` dari garis
## pantai. Sengaja radial (bukan berdasarkan tinggi) supaya `clamp_inside` yang
## memakai proyeksi radial selalu menghasilkan titik yang benar-benar di dalam.

## Garis tengah jalan tanah di koordinat dunia. HARUS sama persis dengan rumus
## `centre` di ground.gdshader: shader yang menggambar jalan, dan fungsi ini yang
## menahan rumput keluar dari jalan, jadi kalau salah satu berubah jalan dan
## rumput jadi tidak sejajar.
static func path_centre(x: float) -> float:
	return PATH_CURVE * sin(x * PATH_FREQUENCY) \
		+ PATH_CURVE * 0.3 * sin(x * PATH_FREQUENCY_B + PATH_PHASE_B)


static func is_inside(x: float, z: float, margin := 0.0) -> bool:
	var point := Vector2(x, z)
	return (island_radius(point.angle()) - point.length()) >= margin


static func clamp_inside(point: Vector2, margin: float) -> Vector2:
	var angle := point.angle()
	var dry := island_radius(angle) - maxf(margin, 0.0)
	var wanted := minf(point.length(), dry)
	return Vector2(cos(angle), sin(angle)) * clampf(wanted, 0.0, HALF)


## Versi statis untuk penyebaran dedaunan yang tidak punya instance Field.
static func can_grow_static(x: float, z: float) -> bool:
	if DISABLE_GRASS:
		return false
	if not is_inside(x, z, GRASS_SHORE_MARGIN):
		return false
	if terrain_height(x, z) < GRASS_MIN_HEIGHT:
		return false
	var gradient := Vector2(
		terrain_height(x + 0.5, z) - terrain_height(x - 0.5, z),
		terrain_height(x, z + 0.5) - terrain_height(x, z - 0.5))
	if gradient.length() > MAX_SLOPE:
		return false
	if absf(z - path_centre(x)) < GRASS_PATH_MARGIN:
		return false
	return true


func can_grow(x: float, z: float) -> bool:
	if DISABLE_GRASS:
		return false
	if not is_inside(x, z, GRASS_SHORE_MARGIN):
		return false
	if surface_height(x, z) < GRASS_MIN_HEIGHT:
		return false
	var gradient := Vector2(
		surface_height(x + 0.5, z) - surface_height(x - 0.5, z),
		surface_height(x, z + 0.5) - surface_height(x, z - 0.5))
	if gradient.length() > MAX_SLOPE:
		return false
	# Jalan tanah tetap bersih: tidak ada rumput di sepanjangnya.
	if absf(z - path_centre(x)) < GRASS_PATH_MARGIN:
		return false
	return true


func allows_foot_effect(point: Vector3, margin := 0.0) -> bool:
	return is_inside(point.x, point.z, margin)


func set_grass_cover(enabled: bool) -> void:
	# Dipakai rumput untuk menghilangkan pola tanah saat rumput disembunyikan.
	_grass_cover = enabled
	if _material != null:
		_material.set_shader_parameter("cover_enabled", enabled)


# ---------------------------------------------------------------- chunking ----

static func _chunk_key(x: float, z: float) -> Vector2i:
	# +0.5 membuat chunk 0 membungkus [-CHUNK/2, CHUNK/2): pusat dunia selalu
	# berada di TENGAH chunk, jadi jangkauan chunk simetris ke segala arah.
	return Vector2i(floori(x / CHUNK + 0.5), floori(z / CHUNK + 0.5))


static func _chunk_origin(key: Vector2i) -> Vector2:
	return Vector2(key) * CHUNK - Vector2(CHUNK, CHUNK) * 0.5


func _focus() -> Vector2:
	return Vector2(player.global_position.x, player.global_position.z) \
		if player != null else Vector2.ZERO


func _recenter(center: Vector2i) -> void:
	_center = center
	_pending.clear()
	for key: Vector2i in _chunks.keys():
		if maxi(absi(key.x - center.x), absi(key.y - center.y)) > CHUNK_RADIUS:
			var nodes: Array = _chunks[key]
			(nodes[0] as Node).queue_free()
			(nodes[1] as Node).queue_free()
			_chunks.erase(key)
	for cz in range(center.y - CHUNK_RADIUS, center.y + CHUNK_RADIUS + 1):
		for cx in range(center.x - CHUNK_RADIUS, center.x + CHUNK_RADIUS + 1):
			var key := Vector2i(cx, cz)
			if not _chunks.has(key) and _chunk_has_land(key):
				_pending.append(key)
	# Yang terdekat dibangun lebih dulu: pemain tidak boleh melihat lubang.
	_pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(center) < b.distance_squared_to(center))


## Chunk yang seluruhnya di laut tidak perlu dibangun: mesh, collider, dan
## draw call-nya hanya buang-buang biaya. Chunk yang SEPARUH di pantai tetap
## dibuat penuh supaya garis airnya terus-menerus (tidak berlubang).
func _chunk_has_land(key: Vector2i) -> bool:
	var center_point := Vector2(key) * CHUNK
	var radial := center_point.length()
	var nearest := maxf(radial - CHUNK * 0.72, 0.0)
	return nearest < island_radius(center_point.angle())


func _build_chunk(key: Vector2i) -> void:
	if _chunks.has(key) or not _chunk_has_land(key):
		return
	var grid := _chunk_grid(key)
	var origin := _chunk_origin(key)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for cz in range(SIDE):
		for cx in range(SIDE):
			var wx := origin.x + float(cx) * CELL
			var wz := origin.y + float(cz) * CELL
			var height: float = grid[cz * SIDE + cx]
			vertices.append(Vector3(wx, height, wz))
			var left: float = grid[cz * SIDE + maxi(cx - 1, 0)]
			var right: float = grid[cz * SIDE + mini(cx + 1, CHUNK_CELLS)]
			var back: float = grid[maxi(cz - 1, 0) * SIDE + cx]
			var front: float = grid[mini(cz + 1, CHUNK_CELLS) * SIDE + cx]
			normals.append(Vector3(left - right, CELL * 2.0, back - front).normalized())
			var tint := _tint(wx, wz)
			colors.append(Color(tint, tint, tint))
	for cz in range(CHUNK_CELLS):
		for cx in range(CHUNK_CELLS):
			var a := cz * SIDE + cx
			var b := a + 1
			var c := a + SIDE
			var d := c + 1
			indices.append_array(PackedInt32Array([a, b, c, b, d, c]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var visual := MeshInstance3D.new()
	visual.name = "Ground_%d_%d" % [key.x, key.y]
	visual.mesh = mesh
	visual.material_override = _material
	visual.extra_cull_margin = 2.0
	add_child(visual)
	var body := StaticBody3D.new()
	body.name = "GroundBody_%d_%d" % [key.x, key.y]
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_trimesh_shape()
	body.add_child(shape)
	add_child(body)
	_chunks[key] = [visual, body]


## Grid tinggi chunk; dihitung sekali lalu disimpan (dipakai mesh, collider,
## dan `surface_height` supaya ketiganya tidak pernah berbeda).
func _chunk_grid(key: Vector2i) -> PackedFloat32Array:
	if _heights.has(key):
		var cached: PackedFloat32Array = _heights[key]
		return cached
	var grid := PackedFloat32Array()
	grid.resize(SIDE * SIDE)
	var origin := _chunk_origin(key)
	for cz in range(SIDE):
		for cx in range(SIDE):
			grid[cz * SIDE + cx] = terrain_height(
				origin.x + float(cx) * CELL, origin.y + float(cz) * CELL)
	_heights[key] = grid
	return grid


func _tint(x: float, z: float) -> float:
	var patch := sin(x * 0.13) * cos(z * 0.11) + 0.55 * sin((x + z) * 0.045)
	return clampf(1.0 + 0.07 * patch, 0.90, 1.10)


func _physics_process(_delta: float) -> void:
	var focus := _focus()
	var center := _chunk_key(focus.x, focus.y)
	if center != _center:
		_recenter(center)
