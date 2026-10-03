extends Node3D
## Jejak kecepatan saat dash/lari: satu pita aditif yang mengikuti jejak posisi
## karakter (ruasnya diambil tiap frame). Sengaja BUKAN afterimage — tidak ada
## salinan pose, kerangka, atau tekstur karakter; yang digambar hanya geometri
## pita, jadi murah untuk HP dan tidak pernah terlihat seperti "badan ganda".
##
## Bentuknya: lebar dan terang di dekat karakter, menyempit serta memudar ke
## belakang, dengan inti hampir putih supaya melewati ambang glow dan benar-benar
## mekar (bukan garis ungu polos). Lebar pita selalu tegak lurus arah pandang
## kamera supaya terbaca sebagai garis gerak dari sudut mana pun.

const Character = preload("res://src/game/mannequin.gd")
const TRAIL_SHADER = preload("res://src/game/speed/trail.gdshader")

## Jumlah ruas pita. Satu ruas per frame saat 60 fps ≈ 0,37 s jejak.
const SEGMENTS := 22
## Lebar pita di dekat karakter (m) dan tinggi minimum di ekor.
const WIDTH := 0.46
## Kekuatan pita saat dash penuh.
const STRENGTH := 1.0

var character: Character
var trail: ImmediateMesh
var _points: Array[Vector3]
var _material: ShaderMaterial
var _strength := 0.0
var _active := false


func _ready() -> void:
	name = "SpeedTrail"
	trail = ImmediateMesh.new()
	var block := MeshInstance3D.new()
	block.mesh = trail
	_material = ShaderMaterial.new()
	_material.shader = TRAIL_SHADER
	_material.set_shader_parameter("strength", 0.0)
	block.material_override = _material
	block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	block.extra_cull_margin = 6.0
	add_child(block)


## Dipanggil dari speed_aura.gd: true = dash/boost sedang jalan. Penggambarannya
## sendiri dilakukan di `_process` (bukan `_physics_process`) karena ImmediateMesh
## adalah sumber daya gambar dan harus ditulis dari thread utama.
func set_active(boosting: bool) -> void:
	_active = boosting


func _process(delta: float) -> void:
	if character == null:
		return
	# Naik cepat, turun pelan: pita muncul seketika saat dash dan memudar halus.
	var target := STRENGTH if _active else 0.0
	_strength = lerpf(_strength, target, 1.0 - exp(-delta * (18.0 if _active else 7.0)))
	if _strength < 0.01:
		_strength = 0.0
	if _active:
		_push(character.global_position + Vector3(0.0, 0.85, 0.0))
	_draw()


## Jumlah ruas jejak yang sedang digambar (dipakai tes).
func sample_count() -> int:
	return _points.size()


func clear() -> void:
	_strength = 0.0
	_active = false
	_points.clear()
	trail.clear_surfaces()
	if _material != null:
		_material.set_shader_parameter("strength", 0.0)


func _push(point: Vector3) -> void:
	# Satu sampel per frame; yang lama terdorong ke ekor. Kalau karakter
	# melompat jauh (teleport/spawn), jejak lama langsung dibuang supaya tidak
	# ada garis menyamping melintasi seluruh pulau.
	if not _points.is_empty() and _points[0].distance_to(point) > 6.0:
		_points.clear()
	_points.push_front(point)
	while _points.size() > SEGMENTS:
		_points.pop_back()


func _draw() -> void:
	if _material != null:
		_material.set_shader_parameter("strength", _strength)
	if _strength <= 0.0 or _points.size() < 2:
		trail.clear_surfaces()
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	# Arah "atas" kamera: pita selalu berdiri tegak di layar.
	var up := camera.global_transform.basis.y.normalized()
	trail.clear_surfaces()
	trail.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var last := float(_points.size() - 1)
	for index in range(_points.size()):
		var t := float(index) / last
		# Kepala lebar dan penuh, ekor menyempit.
		var half := WIDTH * pow(1.0 - t, 0.45)
		var point: Vector3 = _points[index]
		trail.surface_set_uv(Vector2(t, 0.0))
		trail.surface_add_vertex(point + up * half)
		trail.surface_set_uv(Vector2(t, 1.0))
		trail.surface_add_vertex(point - up * half)
	trail.surface_end()
