extends SceneTree
## Gerbang pemandangan dunia (permintaan: "world nya kayak di loading screen").
##
## Yang diuji adalah JANJI ke pemain, bukan sekadar "tidak ada error":
##   1. ada pulau terbang, tebing, laut, reruntuhan batu, dan titik cahaya
##      melayang (bukit tajam tiga segitiga sudah DIHAPUS atas permintaan),
##   2. susunannya mengelilingi PULAU 300 m: laut di segala arah pada permukaan
##      y = 0, sedangkan pulau terbang, tebing, dan pulau batu berdiri di LUAR
##      garis pantai (di seberang air) supaya tidak menutupi medan pemain,
##   3. TIDAK ADA satu pun yang menambah collision atau masuk ke dalam pulau,
##      jadi fisika/gerak pemain tidak berubah,
##   4. jalan tanah benar-benar digambar oleh bahan tanah (parameter shader ada
##      dan menyala), varying world_position benar-benar diisi — dulu tidak,
##      sehingga seluruh pola tanah (termasuk jalan) membaca satu titik nol,
##      dan pita pasir pantai memakai ketinggian tanah supaya mengikuti garis
##      air yang berliku.
##
## Angka bentuknya juga dicatat supaya bisa dibaca dari komentar commit.

const Field = preload("res://src/game/world/field.gd")
const Scenery = preload("res://src/game/world/scenery.gd")
const Pond = preload("res://src/game/world/pond.gd")
var _failures := 0
var _notes := PackedStringArray()
var _reported := {}


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	if _reported.has(message):
		return
	_reported[message] = true
	push_error(message)
	print("::error::", message)


func _run() -> void:
	var scenery := Scenery.new()
	root.add_child(scenery)
	await process_frame
	_test_parts(scenery)
	_test_layout(scenery)
	_test_no_collision(scenery)
	_test_ground_path()
	_test_pond()
	print("[scenery-test] bagian=%d gagal=%d" % [scenery.get_child_count(), _failures])
	print("--- diagnostik ---")
	for note in _notes:
		print(note)
	quit(0 if _failures == 0 else 1)


func _test_parts(scenery: Scenery) -> void:
	for part in ["Floaters", "Sea", "Cliffs", "Island", "Ruins", "LightMotes"]:
		var node := scenery.get_node_or_null(part)
		_check(node != null, "Bagian pemandangan hilang: " + part)
	if scenery.floaters == null or scenery.sea == null or scenery.ruins == null \
			or scenery.motes == null:
		return
	var floater_meshes := 0
	var floater_top := -INF
	var floater_low := INF
	for holder in scenery.floaters.get_children():
		var mesh := holder.get_node_or_null("Floater") as MeshInstance3D
		if mesh == null:
			continue
		floater_meshes += 1
		var bounds := mesh.get_aabb()
		# get_aabb() lokal; posisi holder memberi tinggi melayang sebenarnya.
		floater_top = maxf(floater_top, holder.position.y + bounds.position.y + bounds.size.y)
		floater_low = minf(floater_low, holder.position.y + bounds.position.y)
	# Pemandangan pengganti bukit: harus ADA, harus melayang tinggi supaya
	# terlihat dari padang, dan harus berada di ATAS permukaan laut.
	_check(floater_meshes >= 4, "Pulau terbang kurang dari empat: %d" % floater_meshes)
	_check(floater_top > 12.0,
		"Pulau terbang terlalu rendah untuk terlihat dari padang: %.1f m" % floater_top)
	_check(floater_low > -1.0, "Pulau terbang tenggelam di bawah air: %.1f m" % floater_low)
	var pillars := scenery.ruins.get_child_count()
	_check(pillars >= 5, "Reruntuhan kurang lengkap: %d bagian" % pillars)
	var emitters := 0
	var mote_color := Color.WHITE
	for node in scenery.motes.find_children("*", "GPUParticles3D", true, false):
		var emitter := node as GPUParticles3D
		if emitter.amount > 0:
			emitters += 1
			var glow: StandardMaterial3D = emitter.material_override
			mote_color = glow.albedo_color
	_check(emitters >= 1, "Tidak ada titik cahaya melayang")
	# Partikel harus UNGU (permintaan pengguna), bukan krem/kuning seperti dulu.
	_check(mote_color.b > mote_color.r and mote_color.b > mote_color.g,
		"Partikel melayang bukan ungu: %s" % mote_color)
	_notes.append(("pemandangan: %d pulau terbang (puncak %.0f m, dasar %.0f m), "
		+ "%d blok tebing, %d bagian reruntuhan, %d titik cahaya %s")
		% [floater_meshes, floater_top, floater_low,
			scenery.cliff_count, pillars, emitters, mote_color])


## Susunan pulau 300 m: laut mengelilingi SEMUA arah pada permukaan y = 0,
## pulau terbang dan tebing di luar garis pantai, pulau batu jauh di barat.
func _test_layout(scenery: Scenery) -> void:
	var sea_position := scenery.sea.position
	var sea_mesh := scenery.sea.mesh as PlaneMesh
	_check(sea_mesh != null, "Laut bukan bidang")
	if sea_mesh != null:
		# Laut harus menutup SELURUH pulau 300 m, bukan hanya menyamping.
		_check(sea_mesh.size.x >= Field.SIZE * 2.0,
			"Laut terlalu kecil untuk mengelilingi pulau: %.0f m" % sea_mesh.size.x)
	_check(sea_position.x == 0.0 and sea_position.z == 0.0,
		"Laut tidak mengelilingi pulau: posisi (%.0f, %.0f)"
		% [sea_position.x, sea_position.z])
	_check(sea_position.y < Field.terrain_height(0.0, 0.0),
		"Air tidak lebih rendah dari dataran pulau: y=%.1f" % sea_position.y)
	for holder in scenery.floaters.get_children():
		var mesh := holder.get_node_or_null("Floater") as MeshInstance3D
		if mesh != null:
			_outside_island(mesh, "Pulau terbang")
	var cliffs := scenery.get_node_or_null("Cliffs") as MeshInstance3D
	_check(cliffs != null, "Tebing tidak ditemukan")
	if cliffs != null:
		_outside_island(cliffs, "Tebing")
	if scenery.island != null:
		# Pulau batu berdiri di laut barat, jauh dari garis pantai.
		_outside_island(scenery.island, "Pulau batu")
		var island_bounds := scenery.island.get_aabb()
		_check(island_bounds.position.y + island_bounds.size.y > sea_position.y,
			"Puncak pulau batu tenggelam")
		var west_coast := -Field.island_radius(PI)
		# Jarak minimum pulau batu dari garis pantai: 5% dari ukuran dunia. Pulau
		# batunya sengaja ditaruh jauh (pulau kini 300 m, batunya di x ± 150 m) —
		# cukup terbaca sebagai pulau terpisah di laut tanpa menutupi garis pantai.
		var clearance := Field.SIZE * 0.05
		_check(island_bounds.position.x + island_bounds.size.x < west_coast - clearance,
			"Pulau batu terlalu dekat pantai: x=%.1f (pantai barat %.1f, minimal %.1f m)"
				% [island_bounds.position.x + island_bounds.size.x, west_coast, clearance])
	var sea_width := sea_mesh.size.x if sea_mesh != null else 0.0
	# Tanda kurung WAJIB: tanpa itu % hanya menempel pada potongan terakhir yang
	# tidak punya placeholder, dan GDScript melaporkan "not all arguments
	# converted" sementara catatannya keluar tanpa angka.
	_notes.append(("tata letak: laut %.0f x %.0f m di y=%.2f mengelilingi pulau 300 m, "
		+ "pulau terbang & tebing di luar garis pantai")
		% [sea_width, sea_width, sea_position.y])


## Kolam tengah (ronde 18): lingkaran besar berisi air CETek dengan sebuah pintu
## berdiri di air. Yang dijanjikan ke pemain:
##   1. airnya benar-benar cetek — dasarnya terlihat, bukan kolam dalam,
##   2. bidang air BUNDAR dan tidak pernah menjorok ke daratan kering,
##   3. ada pintu (bingkai + daun + cahaya) dan pantulannya di bawah air.
func _test_pond() -> void:
	var pond := Pond.new()
	root.add_child(pond)
	await process_frame
	var water := pond.water as MeshInstance3D
	_check(water != null, "Kolam tidak punya bidang air")
	if water == null:
		return
	var floor_height := Field.terrain_height(0.0, 0.0)
	var depth := Field.POND_LEVEL - floor_height
	_check(depth > 0.15, "Kolam terlalu dangkal sampai tidak ada air: %.2f m" % depth)
	_check(depth < 1.5, "Kolam harus CETek, dalamnya %.2f m" % depth)
	_check(water.position.y == Field.POND_LEVEL,
		"Permukaan kolam tidak di ketinggian air: %.2f" % water.position.y)
	# Lingkaran: mesh air harus punya banyak segmen di tepi (bukan kotak 4 sudut).
	var arrays := water.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var edge := 0
	for point in points:
		if absf(point.length() - pond.WATER_RADIUS) < 0.01:
			edge += 1
	_check(edge >= 32, "Bidang air tidak bundar: hanya %d titik tepi" % edge)
	# Tepi air harus berada DI DALAM kolam: tanah tepat di garis air masih di
	# bawah permukaan air. Kalau tidak, kepingan air akan mengambang di atas
	# daratan kering dan terlihat seperti genangan di tengah rumput.
	var dry := 0
	for step in range(24):
		var angle := TAU * float(step) / 24.0
		var x := cos(angle) * pond.WATER_RADIUS
		var z := sin(angle) * pond.WATER_RADIUS
		if Field.terrain_height(x, z) > Field.POND_LEVEL:
			dry += 1
	_check(dry == 0, "Ada daratan kering di dalam bidang air di %d dari 24 arah" % dry)
	# Pintu + pantulan.
	var door := pond.door as Node3D
	_check(door != null and door.get_child_count() >= 6,
		"Pintu kurang lengkap: %d bagian" % (door.get_child_count() if door else 0))
	var roles := {}
	if door != null:
		for child in door.get_children():
			roles[child.name] = true
	for role in ["frame", "step", "leaf", "glow"]:
		_check(roles.has(role), "Bagian pintu hilang: " + role)
	var mirror := pond.reflection as Node3D
	_check(mirror != null and mirror.get_child_count() >= 4,
		"Pantulan pintu kurang: %d bagian" % (mirror.get_child_count() if mirror else 0))
	if mirror != null:
		var top := -INF
		for child in mirror.get_children():
			var block := child as MeshInstance3D
			if block == null:
				continue
			var box := block.mesh as BoxMesh
			if box == null:
				continue
			top = maxf(top, block.position.y + box.size.y * 0.5)
		_check(top <= Field.POND_LEVEL + 0.01,
			"Pantulan keluar dari air: puncak %.2f m (air %.2f m)" % [top, Field.POND_LEVEL])
	_notes.append("kolam: r=%.0f m di y=%.2f, dalam %.2f m, pintu %d bagian, pantulan %d bagian"
		% [pond.WATER_RADIUS, Field.POND_LEVEL, depth,
			door.get_child_count() if door else 0,
			mirror.get_child_count() if mirror else 0])
	pond.queue_free()
	await process_frame


## Setiap titik pemandangan besar harus berada di LUAR garis pantai (di laut).
## Pulau terbang, tebing, atau pulau batu yang tumbuh di pulau akan menutupi
## medan tempat pemain berjalan, dan itu tidak kelihatan dari pemeriksaan lain.
func _outside_island(mesh: MeshInstance3D, label: String) -> void:
	if mesh == null or mesh.mesh == null:
		return
	var arrays := mesh.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var inside := 0
	for point in points:
		# Posisi DUNIA: pulau terbang digambar relatif terhadap holder-nya yang
		# melayang jauh dari pusat, jadi titik lokalnya (dekat nol) tidak bisa
		# dipakai langsung — harus lewat transform global dulu.
		var world: Vector3 = mesh.to_global(point)
		if Field.is_inside(world.x, world.z, 0.0):
			inside += 1
	_check(inside == 0, "%s punya %d titik di dalam pulau (harus di laut)"
		% [label, inside])


## Pemandangan tidak boleh menambah collision apa pun: pemain tetap bermain di
## padang yang sama seperti sebelum perubahan.
func _test_no_collision(scenery: Scenery) -> void:
	var bodies := 0
	for node in scenery.find_children("*", "CollisionObject3D", true, false):
		bodies += 1
	_check(bodies == 0, "Pemandangan menambah %d collision" % bodies)


## Angka parameter shader; null (belum disetel) dihitung 0 tanpa membuat
## SCRIPT ERROR, supaya gerbangnya gagal dengan pesan yang jelas.
func _number(material: ShaderMaterial, name: String) -> float:
	var value: Variant = material.get_shader_parameter(name)
	return float(value) if value is float else 0.0


## Jalan tanah digambar oleh shader tanah; kalau parameternya hilang/mati,
## jalan akan lenyap tanpa error apa pun.
func _test_ground_path() -> void:
	var field := Field.new()
	root.add_child(field)
	var material := field.get("_material") as ShaderMaterial
	_check(material != null, "Bahan tanah tidak ditemukan")
	if material == null:
		field.queue_free()
		return
	_check(material.shader != null, "Shader tanah tidak ada")
	var shader := material.shader.code
	_check(shader.contains("world_position = (MODEL_MATRIX"),
		"world_position tidak diisi di vertex(): pola tanah & jalan akan rata")
	_check(shader.contains("path_enabled"), "Shader tanah tidak punya jalan")
	_check(shader.contains("shore_low"), "Shader tanah tidak punya pita pasir pantai")
	var width := _number(material, "path_width")
	var curve := _number(material, "path_curve")
	var frequency := _number(material, "path_frequency")
	_check(width > 0.5, "Lebar jalan tidak masuk akal: %.2f" % width)
	_check(curve > 1.0, "Lekuk jalan tidak masuk akal: %.1f m" % curve)
	_check(frequency > 0.001, "Frekuensi lekuk jalan nol: %.3f" % frequency)
	_notes.append("jalan: lebar %.1f m, lekuk %.0f m, world_position diisi=%s"
		% [width, curve, "ya" if shader.contains("MODEL_MATRIX") else "tidak"])
	field.queue_free()
