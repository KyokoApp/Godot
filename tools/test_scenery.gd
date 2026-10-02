extends SceneTree
## Gerbang pemandangan dunia (permintaan: "world nya kayak di loading screen").
##
## Yang diuji adalah JANJI ke pemain, bukan sekadar "tidak ada error":
##   1. ada bukit, tebing, laut, reruntuhan batu, dan titik cahaya melayang,
##   2. susunannya seperti ilustrasi: laut di barat (-x) dan di bawah kaki,
##      tebing di timur (+x) di luar pagar,
##   3. TIDAK ADA satu pun yang menambah collision atau masuk ke dalam padang,
##      jadi fisika/gerak pemain tidak berubah (gerbang lama tetap sah),
##   4. jalan tanah benar-benar digambar oleh bahan tanah (parameter shader ada
##      dan menyala), dan varying world_position benar-benar diisi — dulu tidak,
##      sehingga seluruh pola tanah (termasuk jalan) membaca satu titik nol.
##
## Angka bentuknya juga dicatat supaya bisa dibaca dari komentar commit.

const Field = preload("res://src/game/world/field.gd")
const Scenery = preload("res://src/game/world/scenery.gd")
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
	print("[scenery-test] bagian=%d gagal=%d" % [scenery.get_child_count(), _failures])
	print("--- diagnostik ---")
	for note in _notes:
		print(note)
	quit(0 if _failures == 0 else 1)


func _test_parts(scenery: Scenery) -> void:
	for part in ["Hills", "Sea", "Cliffs", "Island", "Ruins", "LightMotes"]:
		var node := scenery.get_node_or_null(part)
		_check(node != null, "Bagian pemandangan hilang: " + part)
	if scenery.hills == null or scenery.sea == null or scenery.ruins == null \
			or scenery.motes == null:
		return
	var hill_meshes := 0
	var hill_top := -INF
	for node in scenery.hills.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		hill_meshes += 1
		var bounds := mesh.get_aabb()
		hill_top = maxf(hill_top, bounds.position.y + bounds.size.y)
	_check(hill_meshes >= 2, "Bukit kurang dari dua sabuk: %d" % hill_meshes)
	_check(hill_top > 12.0, "Bukit terlalu rendah untuk terlihat dari padang: %.1f m"
		% hill_top)
	var pillars := scenery.ruins.get_child_count()
	_check(pillars >= 5, "Reruntuhan kurang lengkap: %d bagian" % pillars)
	var emitters := 0
	for node in scenery.motes.find_children("*", "GPUParticles3D", true, false):
		var emitter := node as GPUParticles3D
		if emitter.amount > 0:
			emitters += 1
	_check(emitters >= 1, "Tidak ada titik cahaya melayang")
	_notes.append(("pemandangan: %d sabuk bukit (puncak %.0f m), %d blok tebing, "
		+ "%d bagian reruntuhan, %d titik cahaya") % [hill_meshes, hill_top,
		scenery.cliff_count, pillars, emitters])


## Susunan seperti ilustrasi: laut barat + lebih rendah dari padang, tebing timur.
func _test_layout(scenery: Scenery) -> void:
	var sea_position := scenery.sea.position
	_check(sea_position.x < -Field.HALF, "Laut tidak di sisi barat: x=%.1f" % sea_position.x)
	_check(sea_position.y < -3.0, "Laut tidak lebih rendah dari padang: y=%.1f"
		% sea_position.y)
	var cliffs := scenery.get_node_or_null("Cliffs") as MeshInstance3D
	_check(cliffs != null, "Tebing tidak ditemukan")
	if cliffs != null:
		var bounds := cliffs.get_aabb()
		_check(bounds.position.x > Field.HALF,
			"Tebing masuk ke dalam padang: x=%.1f" % bounds.position.x)
		if scenery.island != null:
			# Pulau harus jauh di laut barat, dan puncaknya di atas permukaan air.
			var island_bounds := scenery.island.get_aabb()
			_check(island_bounds.position.x + island_bounds.size.x
				< -Field.HALF * 4.0,
				"Pulau terlalu dekat: x=%.1f" % (island_bounds.position.x
					+ island_bounds.size.x))
			_check(island_bounds.position.y + island_bounds.size.y
				> scenery.sea.position.y,
				"Puncak pulau tenggelam")
		_notes.append("tata letak: laut y=%.1f x=%.1f, tebing x=%.1f..%.1f"
			% [sea_position.y, sea_position.x, bounds.position.x,
			bounds.position.x + bounds.size.x])


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
	var width := _number(material, "path_width")
	var curve := _number(material, "path_curve")
	var frequency := _number(material, "path_frequency")
	_check(width > 0.5, "Lebar jalan tidak masuk akal: %.2f" % width)
	_check(curve > 1.0, "Lekuk jalan tidak masuk akal: %.1f m" % curve)
	_check(frequency > 0.001, "Frekuensi lekuk jalan nol: %.3f" % frequency)
	_notes.append("jalan: lebar %.1f m, lekuk %.0f m, world_position diisi=%s"
		% [width, curve, "ya" if shader.contains("MODEL_MATRIX") else "tidak"])
	field.queue_free()
