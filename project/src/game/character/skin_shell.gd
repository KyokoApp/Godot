extends Node3D
## "Kulit beranimasi" mannequin: salinan mesh yang selalu menimpa badannya.
##
## Cara kerjanya sama seperti bekas pose (afterimage): satu Skeleton3D bayangan +
## salinan MeshInstance3D, lalu pose tulang disalin tiap kali kerangka sumber
## selesai diperbarui. Bedanya dengan afterimage:
##   * hanya ada SATU salinan (bukan tiga yang memudar), selalu terlihat,
##   * materialnya bahan kulit yang sama dengan material mesh mannequin
##     (character/skin_shell.gdshader), jadi tidak ada sudut yang terlihat polos,
##   * digelembungkan `grow` meter mengikuti normal, jadi ia menutupi mesh
##     mannequin di dalamnya — termasuk bagian yang menonjol di lipatan tajam,
##     karena bahan dalam dan luar identik.
##
## Gerakannya (denyut, aliran energi) dikendalikan `set_pulse()` dari pemain:
## makin cepat badannya bergerak, makin kuat denyutnya. Kecepatan itu dikirim
## juga ke mesh mannequin di dalamnya supaya keduanya berdenyut bersamaan.

const SHADER = preload("res://src/game/character/skin_shell.gdshader")
const OUTLINE = preload("res://src/game/character_outline.gdshader")

## Gelembung kulit (meter). Cukup besar untuk menutup sambungan mannequin,
## cukup kecil supaya siluetnya tidak membengkak.
const GROW := 0.022
## Ambang kecepatan badan untuk denyut penuh (m/s) dan waktu halusnya.
const PULSE_SPEED := 6.0
const PULSE_SMOOTH := 6.0

var pulses := 0
## Material kulit. Dipakai juga oleh mesh mannequin (lapisan dalam) lewat
## `materials()` supaya keduanya tidak bisa berubah sendiri-sendiri.
var skin: ShaderMaterial
var _source: Skeleton3D
var _mirror: Skeleton3D
var _meshes: Array[MeshInstance3D] = []
var _sources: Array[MeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _covers := 0
var _built := false
var _pulse := 0.0
## Frame terakhir kali pose disalin, supaya cadangan di `_process` tidak bekerja
## dua kali saat sinyal `skeleton_updated` sudah berbunyi.
var _mirrored_frame := -1


## Bangun kulit untuk satu kerangka. Aman dipanggil ulang (mis. sesudah isi ulang).
func configure(source: Skeleton3D) -> void:
	_source = source
	_built = false
	for child in get_children():
		child.queue_free()
	_meshes.clear()
	_sources.clear()
	_materials.clear()
	_mirror = null
	if source == null:
		push_error("SkinShell: kerangka sumber kosong")
		return
	skin = _make_material(false)
	_mirror = Skeleton3D.new()
	_mirror.name = "SkinMirror"
	add_child(_mirror)
	for bone in range(source.get_bone_count()):
		_mirror.add_bone(source.get_bone_name(bone))
		_mirror.set_bone_parent(bone, source.get_bone_parent(bone))
		_mirror.set_bone_rest(bone, source.get_bone_rest(bone))
	for origin in _find_meshes(source):
		if origin.mesh == null:
			continue
		var cover := MeshInstance3D.new()
		cover.name = "Skin_%s" % origin.name
		cover.mesh = origin.mesh
		cover.skin = origin.skin
		cover.material_override = skin
		# Jalur skeleton dihitung SESUDAH masuk pohon: `get_path_to` butuh induk
		# bersama yang sudah ada, kalau tidak Godot mengeluh
		# "Parameter common_parent is null" dan mesh-nya tidak terskin.
		add_child(cover)
		cover.skeleton = cover.get_path_to(_mirror)
		# Kulit yang menggambar bayangan: mesh mannequin di dalamnya tidak perlu
		# ikut menggambar bayangan yang sama dua kali.
		cover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		origin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Garis tepi tipis supaya siluetnya tetap terbaca saat langit terang.
		skin.next_pass = _make_outline()
		_meshes.append(cover)
		_sources.append(origin)
		_covers += 1
	var capture := _mirror_poses.bind(source)
	if not source.skeleton_updated.is_connected(capture):
		source.skeleton_updated.connect(capture)
	_mirror_poses(source)
	_built = true


## Cari mesh yang digambar: biasanya anak kerangka, tapi kalau importer
## meletakkannya di luar (sibling), ditelusuri dari seluruh badan karakter.
func _find_meshes(source: Skeleton3D) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for node in source.find_children("*", "MeshInstance3D", true, false):
		found.append(node as MeshInstance3D)
	if found.is_empty() and get_parent() != null:
		for node in get_parent().find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if mesh.mesh == null or is_ancestor_of(mesh):
				continue
			found.append(mesh)
	return found


## Salinan kulit (yang terlihat). Dipakai efek bekas pose supaya yang disalin
## adalah lapisan yang benar-benar digambar.
func covers() -> Array[MeshInstance3D]:
	return _meshes


## Jumlah mesh yang ditutup (dipakai tes).
func cover_count() -> int:
	return _covers


func is_ready() -> bool:
	return _built


## Cadangan: sinyal `skeleton_updated` hanya berbunyi saat kerangka benar-benar
## dipakai menggambar (di headless tidak). Kalau belum ada salinan di frame ini,
## salin di sini — kulit tidak boleh pernah tertinggal dari badannya.
func _process(_delta: float) -> void:
	if not _built or _source == null:
		return
	if _mirrored_frame == Engine.get_process_frames():
		return
	_mirror_poses(_source)


## Denyut kulit dari kecepatan badan: 0 diam, 1 lari penuh.
func set_pulse(speed: float) -> void:
	var wanted := clampf(speed / PULSE_SPEED, 0.0, 1.0)
	_pulse = lerpf(_pulse, wanted, 0.35)
	_apply_pulse()


## Denyut tambahan saat menyerang/mantra (0..1 dari cast layer).
func set_charge(value: float) -> void:
	var level := clampf(value, 0.0, 1.0)
	for material in _materials:
		material.set_shader_parameter("charge", level)


## Pusat + ukuran kulit, dipakai tes untuk membuktikan ia MENUTUPI mannequin.
func shell_bounds() -> AABB:
	var bounds := AABB()
	var first := true
	for mesh in _meshes:
		var box := mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


## Selisih terburuk antara pose kulit dan pose mannequin (meter). Harus ~nol:
## kalau tidak, kulit dan badannya berpisah (mis. sinyal pose tidak tersambung).
func worst_pose_gap() -> float:
	if _source == null or _mirror == null:
		return INF
	if _source.get_bone_count() != _mirror.get_bone_count():
		return INF
	var worst := 0.0
	for bone in range(_source.get_bone_count()):
		var wanted := _source.get_bone_pose_position(bone)
		var got := _mirror.get_bone_pose_position(bone)
		worst = maxf(worst, wanted.distance_to(got))
	return worst


func pulse_value() -> float:
	return _pulse


func materials() -> Array[ShaderMaterial]:
	return _materials


func _make_material(inner: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("grow", 0.0 if inner else GROW)
	_materials.append(material)
	return material


func _make_outline() -> ShaderMaterial:
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE
	outline.set_shader_parameter("outline_width", 0.005)
	return outline


func _apply_pulse() -> void:
	for material in _materials:
		material.set_shader_parameter("pulse", _pulse)


## Salin pose tulang + transform mesh sumber. Dipanggil dari sinyal
## `skeleton_updated` (sesudah semua pengubah pose, sebelum kulit diunggah),
## jadi kulit selalu berada di pose frame yang sama dengan badannya.
func _mirror_poses(source: Skeleton3D) -> void:
	if source == null or _mirror == null or source != _source:
		return
	if source.get_bone_count() != _mirror.get_bone_count():
		return
	global_transform = source.global_transform
	for bone in range(source.get_bone_count()):
		_mirror.set_bone_pose_position(bone, source.get_bone_pose_position(bone))
		_mirror.set_bone_pose_rotation(bone, source.get_bone_pose_rotation(bone))
		_mirror.set_bone_pose_scale(bone, source.get_bone_pose_scale(bone))
	for index in range(_meshes.size()):
		_meshes[index].global_transform = _sources[index].global_transform
	pulses += 1
	_mirrored_frame = Engine.get_process_frames()
