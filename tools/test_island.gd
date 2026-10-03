extends SceneTree
## Gerbang bentuk pulau 500 m × 500 m (permintaan: "ukuran map ubah jadi
## 500m x 500m ajh"; pinggirannya
## jangan bulat atau kotak tapi kayak pulau gitu bergelombang").
##
## Yang diuji adalah JANJI ke pemain, bukan sekadar "tidak ada error":
##   1. dunia benar-benar 500 m × 500 m,
##   2. garis pantainya BERUBAH — radius pulau berubah jauh antar arah, jadi
##      tidak bulat dan tidak kotak,
##   3. ada daratan di tengah dan air di luar: tanah di atas nol di pusat, di
##      bawah nol di luar garis pantai,
##   4. SATU fungsi tinggi dipakai mesh, collider, dan pemain: selisih grid chunk
##      dengan fungsi analitik harus kecil, kalau tidak pemain mengambang atau
##      menembus lantai,
##   5. clamp_inside selalu mengembalikan titik yang benar-benar di darat,
##   6. chunk streaming hidup di sekitar pemain, dan chunk yang seluruhnya di
##      laut tidak pernah dibangun (buang draw call),
##   7. rumput hanya di darat yang kering dan tidak menempel garis pantai.
##
## Bentuk pulau tidak bisa dinilai "mirip pulau" oleh angka; itu urutan mata.
## Yang BISA dijaga angka: tidak bulat, tidak kotak, dan konsisten.

const Field = preload("res://src/game/world/field.gd")
var _failures := 0
var _notes := PackedStringArray()


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
	print("::error::", message)


func _run() -> void:
	_test_size()
	_test_coast_is_wavy()
	_test_land_and_sea()
	await _test_height_agreement()
	_test_clamp_inside()
	await _test_chunks()
	_test_grass()
	print("[island-test] gagal=%d" % _failures)
	# Awalan [island-test] dibuat sama supaya barisnya ikut terbawa ke komentar
	# commit CI (pekerjaan `ringkasan` hanya menggrep awalan itu).
	for note in _notes:
		print("[island-test] ", note)
	quit(0 if _failures == 0 else 1)


func _test_size() -> void:
	_check(is_equal_approx(Field.SIZE, 500.0), "Dunia bukan 500 m: %.0f m" % Field.SIZE)
	_notes.append("dunia: %.0f x %.0f m, dataran pulau %.2f km²"
		% [Field.SIZE, Field.SIZE, _land_area()])


## Luas daratan dari radius rata-rata (diagnostik saja: pemain harus punya pulau
## yang cukup luas untuk jalan-jalan, bukan karang kecil).
func _land_area() -> float:
	const STEPS := 256
	var total := 0.0
	for step in range(STEPS):
		var radius := Field.island_radius(TAU * float(step) / float(STEPS))
		total += radius * radius
	return PI * total / float(STEPS) / 1.0e6


func _test_coast_is_wavy() -> void:
	const STEPS := 96
	var radii := PackedFloat32Array()
	for step in range(STEPS):
		radii.append(Field.island_radius(TAU * float(step) / float(STEPS)))
	var min_radius := radii[0]
	var max_radius := radii[0]
	for value in radii:
		min_radius = minf(min_radius, value)
		max_radius = maxf(max_radius, value)
	var spread := (max_radius - min_radius) / max_radius
	# Bergelombang: radius harus berubah jauh antar arah. Lingkaran sempurna
	# memberi 0%, pulau sungguhan memberi di atas 15%.
	_check(spread > 0.15, "Garis pantai hampir bulat: radius %.0f..%.0f m"
		% [min_radius, max_radius])
	# Tidak bulat: hampir semua arah harus punya radius yang berbeda.
	var distinct := 0
	for value in radii:
		if absf(value - radii[0]) > 1.0:
			distinct += 1
	_check(distinct > STEPS * 0.9, "Radius pulau sama di hampir semua arah (bulat)")
	# Tidak kotak: pulau tidak boleh menyentuh tepi dunia, dan radius di setiap
	# arah harus jauh dari setengah diagonal (ciri bentuk persegi).
	var diagonal := Field.HALF * 1.4142
	for value in radii:
		_check(value < Field.HALF * 0.95,
			"Pulau menyentuh tepi dunia (kotak?): radius %.0f m" % value)
		_check(value < diagonal * 0.95,
			"Radius melewati setengah diagonal (kotak?): %.0f m" % value)
		_check(value > 100.0, "Pulau terlalu kecil di salah satu arah: %.0f m" % value)
	_notes.append("pulau: radius %.0f..%.0f m (berubah %.0f%% antar arah)"
		% [min_radius, max_radius, spread * 100.0])


func _test_land_and_sea() -> void:
	# Tengah pulau: daratan di atas permukaan air.
	var middle := Field.terrain_height(0.0, 0.0)
	_check(middle > 2.0, "Tengah pulau tidak di atas air: %.1f m" % middle)
	# Di luar garis pantai: dasar laut di bawah air dan tidak dihitung "dalam".
	for step in range(16):
		var angle := TAU * float(step) / 16.0
		var radius := Field.island_radius(angle) + 60.0
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		_check(Field.terrain_height(x, z) < 0.0,
			"Di luar pantai masih ada darat pada sudut %.1f" % angle)
		_check(not Field.is_inside(x, z, 0.0),
			"Titik di laut dihitung di dalam pulau pada sudut %.1f" % angle)
	# Tepi dunia (500 m) pasti air: pemain tidak pernah bisa jalan keluar pulau.
	_check(Field.terrain_height(Field.HALF - 1.0, 0.0) < 0.0,
		"Tepi dunia timur masih darat")
	_check(Field.terrain_height(-Field.HALF + 1.0, 0.0) < 0.0,
		"Tepi dunia barat masih darat")
	# Garis pantai harus tepat di nol: di situlah air dan pasir bertemu.
	var coast_angle := 1.3
	var coast_radius := Field.island_radius(coast_angle)
	var coast_height := Field.terrain_height(cos(coast_angle) * coast_radius,
		sin(coast_angle) * coast_radius)
	_check(absf(coast_height) < 0.05,
		"Tinggi tanah tidak nol di garis pantai: %.2f m" % coast_height)


## Mesh, collider, dan pemain membaca tinggi yang sama. Grid chunk dihitung dari
## fungsi analitik lalu diinterpolasi; bedanya harus kecil (beberapa milimeter),
## kalau tidak pemain mengambang di atas tanah atau menembusnya.
func _test_height_agreement() -> void:
	var field := Field.new()
	root.add_child(field)
	# Tunggu chunk selesai di-stream: kalau tidak, semua titik jatuh ke fungsi
	# analitik dan selisihnya selalu 0 — tesnya hijau tapi tidak menguji apa pun.
	for _frame in range(60):
		await process_frame
	var worst := 0.0
	var points := 0
	for step in range(24):
		var angle := TAU * float(step) / 24.0
		var radius := (Field.island_radius(angle) - 10.0) * (0.3 + 0.2 * float(step % 3))
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		worst = maxf(worst, absf(field.surface_height(x, z) - Field.terrain_height(x, z)))
		points += 1
	_check(worst < 0.05, "Tinggi grid vs fungsi analitik beda %.3f m" % worst)
	_notes.append("tinggi: %d titik, selisih grid vs analitik %.4f m" % [points, worst])
	field.queue_free()
	await process_frame


func _test_clamp_inside() -> void:
	for step in range(24):
		var angle := TAU * float(step) / 24.0
		var radius := Field.island_radius(angle) + 120.0
		var outside := Vector2(cos(angle), sin(angle)) * radius
		var fixed := Field.clamp_inside(outside, 14.0)
		_check(Field.is_inside(fixed.x, fixed.y, 13.0),
			"clamp_inside mengembalikan titik di luar pulau pada sudut %.1f" % angle)
		_check(fixed.length() <= outside.length() + 0.001,
			"clamp_inside mendorong pemain menjauh pada sudut %.1f" % angle)
		# Titik yang sudah di dalam tidak boleh ikut digeser. Toleransi 1 cm:
		# sudut dihitung ulang lewat atan2 (bedanya ~4e-6 rad) dan itu dikalikan
		# radius ~150 m, jadi is_equal_approx (1e-5 m) terlalu ketat.
		var inside := Vector2(cos(angle), sin(angle)) * (Field.island_radius(angle) * 0.5)
		_check(Field.clamp_inside(inside, 14.0).distance_to(inside) < 0.01,
			"Titik di dalam pulau ikut digeser pada sudut %.1f" % angle)
	_notes.append("clamp_inside: titik di laut dikembalikan ke darat (margin 14 m)")


func _test_chunks() -> void:
	var field := Field.new()
	root.add_child(field)
	for _frame in range(120):
		await process_frame
	var chunks: Dictionary = field.get("_chunks")
	_check(chunks.size() > 8, "Chunk tanah tidak dibangun: %d" % chunks.size())
	var sea_chunks := 0
	for key: Vector2i in chunks.keys():
		# Pusat chunk yang jauh di laut tidak boleh pernah dibangun: mesh,
		# collider, dan draw call-nya cuma buang-buang biaya.
		var center := Vector2(key) * Field.CHUNK
		if not Field.is_inside(center.x, center.y, -Field.CHUNK):
			sea_chunks += 1
	_check(sea_chunks == 0, "%d chunk di laut dibangun sia-sia" % sea_chunks)
	_notes.append("chunk: %d chunk hidup dari %d kandidat (jangkauan %.0f m)"
		% [chunks.size(), (Field.CHUNK_RADIUS * 2 + 1) ** 2,
		Field.CHUNK * (float(Field.CHUNK_RADIUS) + 0.5)])
	field.queue_free()
	await process_frame


func _test_grass() -> void:
	var field := Field.new()
	root.add_child(field)
	await process_frame
	_check(field.can_grow(0.0, 0.0), "Rumput tidak tumbuh di tengah pulau")
	for step in range(12):
		var angle := TAU * float(step) / 12.0
		var coast := Field.island_radius(angle) - 2.0
		_check(not field.can_grow(cos(angle) * coast, sin(angle) * coast),
			"Rumput tumbuh menempel garis pantai pada sudut %.1f" % angle)
		var sea := Field.island_radius(angle) + 25.0
		_check(not field.can_grow(cos(angle) * sea, sin(angle) * sea),
			"Rumput tumbuh di laut pada sudut %.1f" % angle)
	field.queue_free()
	await process_frame
