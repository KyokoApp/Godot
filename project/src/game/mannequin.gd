extends Node3D
## Mannequin UAL — satu-satunya karakter. Satu skeleton, dua perpustakaan animasi
## (UAL1 + UAL2 = 85 klip) yang dimuat ke SATU AnimationPlayer, jadi transisi,
## cross-fade, dan lapisan tubuh atas berjalan di clock yang sama.
##
## Perbaikan animasi yang dikerjakan di sini:
##  1. Tidak ada lagi rig bayangan + penyalinan pose tiap frame (dulu UAL2 diputar
##     di model tersembunyi lalu pose-nya disalin manual — lambat dan patah).
##  2. Mode loop tiap klip disetel benar dari katalog (loop vs sekali vs tahan).
##  3. Kecepatan main dicocokkan dengan langkah hasil ukur (tidak meluncur).
##  4. Offset tanah per klip menjaga kaki tidak tenggelam di klip rendah.
##  5. Tubuh mannequin dilapisi "kulit beranimasi" (character/skin_shell.gd):
##     salinan mesh yang digelembungkan sedikit dan memakai bahan kulit yang sama
##     dengan mesh di dalamnya, jadi tulang/sambungan mannequin tidak pernah
##     terlihat polos. Denyutnya mengikuti kecepatan badan.

signal clip_changed(clip: String)

enum Mode { LOCOMOTION, ACTION, SHOWCASE, HELD }

const MODEL = preload("res://assets/mannequin/UAL1_Standard.glb")
const SkinShell = preload("res://src/game/character/skin_shell.gd")
const SKIN_SHADER = preload("res://src/game/character/skin_shell.gdshader")
const COMBAT_MODEL = preload("res://assets/combat/UAL2_Standard.glb")
## Klip dash dari Mixamo. Berisi tulang `mixamorig:*` yang TIDAK sama dengan
## tulang UAL, jadi nama tulaangnya diterjemahkan saat digabung (lihat
## _merge_dash_library). Ganti berkas ini dengan animasi dash sungguhan tidak
## butuh perubahan kode: nama animasi tetap "dash/Dash".
const DASH_MODEL_PATH := "res://assets/combat/dash.fbx"
const OUTLINE = preload("res://src/game/character_outline.gdshader")
const CastLayer = preload("res://src/game/animation/cast_layer.gd")
const Catalog = preload("res://src/game/animation/catalog.gd")
const Metrics = preload("res://src/game/animation/anim_metrics.gd")
const IDLE := "Idle_Loop"
const AIR_CLIP := "Jump_Loop"
const COMBAT_LIBRARY := "ual2"
const DASH_LIBRARY := "dash"
## Nama animasi di pustaka dash — dipilih sendiri, bukan nama stack Mixamo.
const DASH_ANIMATION := "Dash"
## Durasi minimum klip dash (detik). Pose Mixamo bisa terimpor sepanjang SATU
## frame (0,017 s); tanpa batas ini dash-nya cuma kedip. Harus sama dengan
## Player.DASH_TIME.
const DASH_MIN_LENGTH := 0.22
## Terjemahan tulang Mixamo -> tulang UAL mannequin. Keduanya manusia biasa
## dengan perbandingan yang mirip, jadi pose-nya pindah dengan benar.
const DASH_BONES := {
	"mixamorig:Hips": "pelvis",
	"mixamorig:Spine": "spine_01",
	"mixamorig:Spine1": "spine_02",
	"mixamorig:Spine2": "spine_03",
	"mixamorig:Neck": "neck_01",
	"mixamorig:Head": "Head",
	"mixamorig:LeftShoulder": "clavicle_l",
	"mixamorig:LeftArm": "upperarm_l",
	"mixamorig:LeftForeArm": "lowerarm_l",
	"mixamorig:LeftHand": "hand_l",
	"mixamorig:RightShoulder": "clavicle_r",
	"mixamorig:RightArm": "upperarm_r",
	"mixamorig:RightForeArm": "lowerarm_r",
	"mixamorig:RightHand": "hand_r",
	"mixamorig:LeftUpLeg": "thigh_l",
	"mixamorig:LeftLeg": "calf_l",
	"mixamorig:LeftFoot": "foot_l",
	"mixamorig:LeftToeBase": "ball_l",
	"mixamorig:RightUpLeg": "thigh_r",
	"mixamorig:RightLeg": "calf_r",
	"mixamorig:RightFoot": "foot_r",
	"mixamorig:RightToeBase": "ball_r",
	"mixamorig:LeftHandThumb1": "thumb_01_l",
	"mixamorig:LeftHandThumb2": "thumb_02_l",
	"mixamorig:LeftHandThumb3": "thumb_03_l",
	"mixamorig:LeftHandThumb4": "thumb_04_leaf_l",
	"mixamorig:LeftHandIndex1": "index_01_l",
	"mixamorig:LeftHandIndex2": "index_02_l",
	"mixamorig:LeftHandIndex3": "index_03_l",
	"mixamorig:LeftHandIndex4": "index_04_leaf_l",
	"mixamorig:LeftHandMiddle1": "middle_01_l",
	"mixamorig:LeftHandMiddle2": "middle_02_l",
	"mixamorig:LeftHandMiddle3": "middle_03_l",
	"mixamorig:LeftHandMiddle4": "middle_04_leaf_l",
	"mixamorig:LeftHandRing1": "ring_01_l",
	"mixamorig:LeftHandRing2": "ring_02_l",
	"mixamorig:LeftHandRing3": "ring_03_l",
	"mixamorig:LeftHandRing4": "ring_04_leaf_l",
	"mixamorig:LeftHandPinky1": "pinky_01_l",
	"mixamorig:LeftHandPinky2": "pinky_02_l",
	"mixamorig:LeftHandPinky3": "pinky_03_l",
	"mixamorig:LeftHandPinky4": "pinky_04_leaf_l",
	"mixamorig:RightHandThumb1": "thumb_01_r",
	"mixamorig:RightHandThumb2": "thumb_02_r",
	"mixamorig:RightHandThumb3": "thumb_03_r",
	"mixamorig:RightHandThumb4": "thumb_04_leaf_r",
	"mixamorig:RightHandIndex1": "index_01_r",
	"mixamorig:RightHandIndex2": "index_02_r",
	"mixamorig:RightHandIndex3": "index_03_r",
	"mixamorig:RightHandIndex4": "index_04_leaf_r",
	"mixamorig:RightHandMiddle1": "middle_01_r",
	"mixamorig:RightHandMiddle2": "middle_02_r",
	"mixamorig:RightHandMiddle3": "middle_03_r",
	"mixamorig:RightHandMiddle4": "middle_04_leaf_r",
	"mixamorig:RightHandRing1": "ring_01_r",
	"mixamorig:RightHandRing2": "ring_02_r",
	"mixamorig:RightHandRing3": "ring_03_r",
	"mixamorig:RightHandRing4": "ring_04_leaf_r",
	"mixamorig:RightHandPinky1": "pinky_01_r",
	"mixamorig:RightHandPinky2": "pinky_02_r",
	"mixamorig:RightHandPinky3": "pinky_03_r",
	"mixamorig:RightHandPinky4": "pinky_04_leaf_r",
}
const FADE := 0.10
## Serah-terima aksi → lokomosi. Sekecil mungkin: dulu 0,24 s, dan selama
## cross-fade itu badan masih memakai pose akhir klip aksi — itulah "jeda"
## yang terlihat setelah dash/serangan sebelum kakinya jalan lagi.
const HANDOFF := 0.08
## Pemulihan setelah mendarat: klip mendarat hanya dipakai sesaat, lalu badan
## kembali ke gait supaya tidak terasa berhenti mendadak.
const LAND_RECOVERY := 0.28
const OFFSET_SPEED := 6.0

var animation: AnimationPlayer
var skeleton: Skeleton3D
## Kerangka yang terlihat. Efek (bekas pose, tapak api, aura) dan tes membidik
## `avatar`; pada mannequin kerangka itu sama dengan `skeleton`.
var avatar: Skeleton3D
var skin: SkinShell
var cast_layer: CastLayer
var metrics: Dictionary = {}
var mode := Mode.LOCOMOTION
var clip := IDLE
var gait := IDLE
var ground_offset := 0.0
var playback_scale := 1.0
var _hold_after := false
var _action_left := 0.0
## Skala kecepatan lokomosi terakhir. Dipakai lagi saat aksi selesai supaya kaki
## tidak sempat memutar 1x (kelamaan) selama satu frame sebelum pemain menyetel
## skala yang benar lagi.
var _locomotion_scale := 1.0
var _model: Node3D
var _skin_material: ShaderMaterial
var _library: AnimationLibrary


func _ready() -> void:
	var model: Node3D = MODEL.instantiate()
	# Koreksi arah model yang dipakai project lama (menghadap -Z Godot).
	model.rotation.y = PI
	add_child(model)
	_model = model
	animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if animation == null or skeleton == null:
		push_error("Mannequin: AnimationPlayer/Skeleton3D hilang")
		return
	avatar = skeleton
	# Klip sekali jalan yang sudah habis langsung menyerahkan badan ke gait;
	# tanpa ini ada jendela diam di frame terakhir (terlihat seperti jalan di tempat
	# atau pose kaku) sebelum timer aksi selesai.
	animation.animation_finished.connect(_on_animation_finished)
	_merge_combat_library()
	_apply_material()
	_setup_skin()
	_configure_clips()
	metrics = Metrics.measure_catalog(animation, skeleton, Catalog)
	animation.play(Catalog.play_name(IDLE), 0.0)
	animation.advance(0.0)
	_setup_cast_layer()
	print("[mannequin] %d klip dimuat, %d metrik terukur" % [
		animation.get_animation_list().size(), metrics.size()])


func _merge_combat_library() -> void:
	# UAL2 punya tulang, rest pose, dan mesh yang sama; pustakanya dipindah ke
	# AnimationPlayer utama supaya semua klip berbagi satu clock animasi.
	var source: Node3D = COMBAT_MODEL.instantiate()
	var source_player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if source_player == null:
		push_error("Mannequin: UAL2 tidak punya AnimationPlayer")
		source.free()
		return
	_library = source_player.get_animation_library("")
	if _library == null:
		push_error("Mannequin: pustaka UAL2 kosong")
		source.free()
		return
	animation.add_animation_library(COMBAT_LIBRARY, _library)
	source.free()
	_merge_dash_library()


## Gabungkan klip dash Mixamo ke AnimationPlayer utama. Dua hal dikerjakan:
##   1. nama tulang `mixamorig:*` diterjemahkan ke tulang UAL mannequin, karena
##      pustaka ini memakai kerangka yang berbeda dari UAL;
##   2. animasinya diberi nama tetap ("Dash") di pustaka "dash", jadi kode tidak
##      bergantung pada nama stack di dalam berkas Mixamo.
func _merge_dash_library() -> void:
	# Dimuat dengan load() (bukan preload) supaya kalau impor FBX-nya gagal,
	# permainan tetap jalan dan tes yang melaporkan masalah tetap jelas.
	var packed: PackedScene = load(DASH_MODEL_PATH) as PackedScene
	if packed == null:
		push_error("Mannequin: dash.fbx tidak bisa dimuat (impor gagal?)")
		return
	var source: Node3D = packed.instantiate()
	var player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		push_error("Mannequin: dash.fbx tidak memuat AnimationPlayer")
		source.free()
		return
	var library: AnimationLibrary = null
	for name: String in player.get_animation_library_list():
		var candidate: AnimationLibrary = player.get_animation_library(name)
		if candidate != null and not candidate.get_animation_list().is_empty():
			library = candidate
			break
	if library == null:
		push_error("Mannequin: dash.fbx tidak punya pustaka animasi")
		source.free()
		return
	var prefix := _bone_path_prefix()
	var merged := AnimationLibrary.new()
	var mapped := 0
	for name: String in library.get_animation_list():
		var anim: Animation = library.get_animation(name)
		mapped += _remap_dash_bones(anim, prefix)
		anim.length = maxf(anim.length, DASH_MIN_LENGTH)
		merged.add_animation(DASH_ANIMATION, anim)
	if animation.has_animation_library(DASH_LIBRARY):
		animation.remove_animation_library(DASH_LIBRARY)
	animation.add_animation_library(DASH_LIBRARY, merged)
	source.free()
	print("[mannequin] dash.fbx: %d trek diterjemahkan ke tulang UAL" % mapped)


## Awalan jalur trek animasi UAL (mis. "GeneralSkeleton:"). Dibaca dari klip yang
## sudah ada supaya tidak menebak nama node skeleton.
func _bone_path_prefix() -> String:
	var reference: Animation = animation.get_animation(Catalog.play_name(IDLE))
	if reference == null:
		return ""
	for track in range(reference.get_track_count()):
		var path := str(reference.track_get_path(track))
		var colon := path.find(":")
		if colon > 0:
			return path.substr(0, colon + 1)
	return ""


## Terjemahkan nama tulang pada semua trek satu animasi. Trek yang tulaangnya
## tidak ada di peta DIBUANG (bukan dibiarkan): jalur "…:mixamorig:Hips" tidak
## akan pernah ketemu di kerangka UAL, dan engine akan mengeluh tiap frame.
func _remap_dash_bones(anim: Animation, prefix: String) -> int:
	var mapped := 0
	var dropped := PackedStringArray()
	for track in range(anim.get_track_count() - 1, -1, -1):
		var path := str(anim.track_get_path(track))
		var bone := _bone_of_path(path)
		var target := _dash_bone_target(bone)
		if target.is_empty():
			dropped.append(bone)
			anim.remove_track(track)
			continue
		anim.track_set_path(track, NodePath(prefix + target))
		mapped += 1
	# Dicetak supaya kalau importer mengubah nama tulangnya, bentuk aslinya
	# langsung kelihatan di log CI tanpa harus menebak.
	if not dropped.is_empty():
		print("[mannequin] dash.fbx awalan jalur='", prefix, "' trek tidak dikenali: ",
			", ".join(dropped))
	return mapped


## Nama tulang UAL untuk satu nama tulang Mixamo. Dicoba dua kali: persis dulu,
## lalu lewat bentuk yang dinormalkan. Importer Godot tidak menjamin nama asli
## tetap utuh — titik dan tanda dua bisa berubah, awalan "mixamorig" bisa hilang.
func _dash_bone_target(bone: String) -> String:
	if DASH_BONES.has(bone):
		return DASH_BONES[bone]
	var wanted := _normalise_bone(bone)
	for key: String in DASH_BONES:
		if _normalise_bone(key) == wanted:
			return DASH_BONES[key]
	return ""


## Bentuk pembanding: huruf kecil, awalan "mixamorig" dan semua pemisah dibuang.
## "mixamorig:Hips", "mixamorig_Hips", dan "Hips" jadi sama.
func _normalise_bone(name: String) -> String:
	var out := name.to_lower()
	out = out.replace("mixamorig", "")
	for marker in [":", "_", "-", " ", ".", "/"]:
		out = out.replace(marker, "")
	return out


## Nama tulang dari jalur trek, apa pun awalahnya ("Skeleton:Bone" atau
## "Armature/Skeleton3D/Bone").
func _bone_of_path(path: String) -> String:
	var colon := path.find(":")
	if colon >= 0:
		return path.substr(colon + 1)
	var slash := path.rfind("/")
	if slash >= 0:
		return path.substr(slash + 1)
	return path


## Mesh mannequin memakai bahan kulit yang sama dengan lapisan luarnya. Jadi
## sudut mana pun yang menonjol di lipatan tajam (siku, lutut, pinggul) tetap
## berwarna kulit — tidak pernah ada bagian mannequin polos yang terlihat.
func _apply_material() -> void:
	_skin_material = ShaderMaterial.new()
	_skin_material.shader = SKIN_SHADER
	_skin_material.set_shader_parameter("grow", 0.0)
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE
	outline.set_shader_parameter("outline_width", 0.005)
	# Putih tipis: mesh mannequin kini hitam gelap, jadi tepinya harus terang.
	outline.set_shader_parameter("outline_color", Color.WHITE)
	_skin_material.next_pass = outline
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = _skin_material


## Kulit beranimasi: salinan mesh yang selalu menimpa mannequin
## (lihat character/skin_shell.gd).
func _setup_skin() -> void:
	skin = SkinShell.new()
	skin.name = "SkinShell"
	add_child(skin)
	skin.configure(skeleton)


## Denyut kulit dari kecepatan badan (dipakai _physics_process di bawah).
func _update_motion(speed: float, boosting := false) -> void:
	if skin == null:
		return
	skin.set_pulse(speed if not boosting else speed * 1.35)


## Mesh yang benar-benar digambar (lapisan kulit). Efek seperti bekas pose
## menyalin dari sini supaya yang disalin bukan mesh dalam yang tak terlihat.
func visible_meshes() -> Array[MeshInstance3D]:
	if skin == null:
		return []
	return skin.covers()


## Mode ringan: dulu mengubah kerumitan pola energi kulit. Sejak kulit jadi
## HITAM POLOS (garis energi dihapus), tidak ada lagi pola yang bisa dikurangi —
## pemanggil di `performance_panel.gd` tetap memakai fungsi ini, dan parameter
## `vein_*` yang masih dideklarasikan di shader tetap diberi nilai valid supaya
## tidak ada setelan yang menggantung. Tampilan kulit tidak berubah lagi.
func set_light_cloth(light: bool) -> void:
	if _skin_material == null:
		return
	# Kulit polos: satu hash bercak + rim statis. Nilai ini sudah tidak dipakai
	# shader, tapi tetap disetel supaya bahan tidak menyimpan parameter kosong.
	_skin_material.set_shader_parameter("vein_scale", 12.0 if light else 16.5)
	_skin_material.set_shader_parameter("vein_width", 0.130 if light else 0.105)
	if skin != null and skin.skin != null:
		skin.skin.set_shader_parameter("vein_scale", 12.0 if light else 16.5)
		skin.skin.set_shader_parameter("vein_width", 0.130 if light else 0.105)


func _configure_clips() -> void:
	for entry in Catalog.entries():
		var name: String = entry["name"]
		var play_name: String = Catalog.play_name(name)
		if not animation.has_animation(play_name):
			push_error("Mannequin: klip hilang dari berkas: " + play_name)
			continue
		var source := animation.get_animation(play_name)
		source.loop_mode = Animation.LOOP_LINEAR if Catalog.is_loop(name) \
			else Animation.LOOP_NONE


func _setup_cast_layer() -> void:
	if not animation.has_animation(CastLayer.CLIP):
		push_error("Mannequin: klip casting hilang")
		return
	cast_layer = CastLayer.new()
	cast_layer.name = "UpperBodyCast"
	skeleton.add_child(cast_layer)
	cast_layer.configure(animation.get_animation(CastLayer.CLIP))
	if cast_layer.tracks.is_empty():
		push_error("Mannequin: filter tulang casting kosong")


# ------------------------------------------------------------- lokomosi ----

func natural_speed(name: String) -> float:
	var measured: Dictionary = metrics.get(name, {})
	var speed := float(measured.get("natural_speed", 0.0))
	return speed if speed > 0.05 else 1.0


func set_locomotion(name: String, playback_speed := 1.0) -> void:
	_locomotion_scale = clampf(playback_speed, 0.1, 3.0)
	if mode == Mode.HELD:
		# Pose tahan (klip aksi yang berhenti di frame terakhir) DILEPAS begitu
		# pemain meminta gait. Dulu mode HELD juga menolak mengganti klip, jadi
		# badannya berjalan sambil membeku seperti foto — "kayak difoto".
		mode = Mode.LOCOMOTION
	elif mode != Mode.LOCOMOTION:
		# Klip pilihan panel atau aksi sekali jalan tidak boleh ditimpa pemain.
		gait = name
		return
	gait = name
	mode = Mode.LOCOMOTION
	if name != clip:
		_play(name, FADE, _locomotion_scale)
	else:
		animation.speed_scale = _locomotion_scale


func set_air_clip(name: String, playback_speed := 1.0) -> void:
	# Klip udara dipilih pemain (lompat), bukan dari band kecepatan.
	mode = Mode.LOCOMOTION
	gait = name
	if name != clip:
		_play(name, 0.1, playback_speed)
	else:
		animation.speed_scale = clampf(playback_speed, 0.1, 3.0)


func play_action(name: String, max_time := 0.0) -> float:
	var measured: Dictionary = metrics.get(name, {})
	var length := float(measured.get("length", 0.0))
	if length <= 0.0 or not animation.has_animation(Catalog.play_name(name)):
		return 0.0
	_hold_after = Catalog.holds_last_frame(name)
	mode = Mode.ACTION
	# Klip boleh lebih panjang daripada aksinya. Tanpa batas ini kaki berdiam di
	# SISA klip yang tidak dipakai selama seperempat detik sebelum kembali jalan —
	# persis "jeda" yang dikeluhkan.
	_action_left = length if max_time <= 0.0 else minf(length, max_time)
	_play(name, FADE, 1.0)
	return length


func play_landing(name: String) -> void:
	# Dipakai saat pemain menyentuh tanah: klip mendarat dimainkan sebentar saja.
	_hold_after = false
	var length := length_of(name)
	if length <= 0.0 or not animation.has_animation(Catalog.play_name(name)):
		return_to_locomotion()
		return
	mode = Mode.ACTION
	_action_left = minf(length, LAND_RECOVERY)
	_play(name, 0.10, 1.0)


func _on_animation_finished(finished: String) -> void:
	if mode != Mode.ACTION or animation == null:
		return
	if animation.current_animation != finished:
		return # Klip lama yang di-cross-fade, bukan aksi yang sedang jalan.
	if _hold_after:
		freeze_at_last_frame()
	else:
		return_to_locomotion()


func play_showcase(name: String) -> void:
	# Dipilih manual dari panel animasi: loop klip loop, tahan klip sekali.
	_hold_after = Catalog.holds_last_frame(name)
	mode = Mode.SHOWCASE if Catalog.is_loop(name) else Mode.ACTION
	_action_left = length_of(name)
	_play(name, FADE, 1.0)


func return_to_locomotion() -> void:
	_hold_after = false
	_action_left = 0.0
	mode = Mode.LOCOMOTION
	# gait bisa saja masih berisi klip udara (set_air_clip menimpanya). Jangan
	# diputar lagi di darat — pulang ke Idle, lalu pemain memilih gait aslinya
	# di frame berikutnya.
	if gait == AIR_CLIP:
		gait = IDLE
	_play(gait, HANDOFF, _locomotion_scale)


func freeze_at_last_frame() -> void:
	mode = Mode.HELD
	_hold_after = true


func current_label() -> String:
	return Catalog.label_for(clip)


func length_of(name: String) -> float:
	var measured: Dictionary = metrics.get(name, {})
	return float(measured.get("length", 0.0))


func description_of(name: String) -> String:
	var entry := Catalog.find(name)
	return str(entry.get("desc", "")) if not entry.is_empty() else ""


func set_playback_scale(value: float) -> void:
	playback_scale = clampf(value, 0.1, 2.0)
	# Hanya klip tampilan yang ikut lambat; lokomosi tetap sinkron dengan badan.
	if animation != null and (mode == Mode.ACTION or mode == Mode.SHOWCASE):
		animation.speed_scale = playback_scale


func progress() -> float:
	if animation == null:
		return 0.0
	var length := animation.current_animation_length
	if length <= 0.0:
		return 0.0
	return clampf(animation.current_animation_position / length, 0.0, 1.0)


func is_busy() -> bool:
	return mode == Mode.ACTION or mode == Mode.SHOWCASE


func start_cast() -> void:
	if cast_layer != null:
		cast_layer.begin()


func _play(name: String, fade: float, playback_speed: float) -> void:
	clip = name
	var scale := playback_speed
	if mode == Mode.ACTION or mode == Mode.SHOWCASE:
		scale *= playback_scale
	animation.speed_scale = clampf(scale, 0.1, 3.0)
	animation.play(Catalog.play_name(name), fade)
	animation.advance(0.0)
	clip_changed.emit(clip)


func _physics_process(delta: float) -> void:
	if animation == null:
		return
	# Timer sendiri, bukan sinyal: deterministik di headless dan tidak bisa
	# terlewat saat klip diganti cepat dari panel.
	if mode == Mode.ACTION and _action_left > 0.0:
		_action_left = maxf(0.0, _action_left - delta * maxf(animation.speed_scale, 0.01))
		if _action_left <= 0.0:
			if _hold_after:
				mode = Mode.HELD
				animation.pause()
			else:
				return_to_locomotion()
	# Denyut kulit mengikuti kecepatan badan: dibaca langsung dari badan pemain
	# (induk node ini) supaya tidak perlu ada pemanggil tambahan tiap frame.
	var body := get_parent()
	if body is CharacterBody3D:
		_update_motion((body as CharacterBody3D).velocity.length(), false)
	# Kulit ikut menyala saat tubuh atas memainkan mantra/serangan.
	if skin != null:
		var casting := cast_layer != null and cast_layer.active
		skin.set_charge(1.0 if casting else 0.0)
	# Offset tanah halus: klip rendah (guling, meluncur) tidak menenggelamkan kaki.
	var measured: Dictionary = metrics.get(clip, {})
	var target := float(measured.get("ground_offset", 0.0))
	ground_offset = lerpf(ground_offset, target, 1.0 - exp(-OFFSET_SPEED * delta))
	_model.position.y = ground_offset


# ----------------------------------------------- kontak kaki untuk efek ----

func foot_pose(left: bool) -> Transform3D:
	var bone := skeleton.find_bone("foot_l" if left else "foot_r")
	if bone < 0:
		return global_transform
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone)


func foot_clearance(left: bool) -> float:
	var bone := skeleton.find_bone("foot_l" if left else "foot_r")
	if bone < 0:
		return 0.1
	var rest := skeleton.get_bone_global_rest(bone)
	return clampf(rest.origin.y, 0.06, 0.18)


func foot_stride_lift(left: bool) -> float:
	var bone := skeleton.find_bone("foot_l" if left else "foot_r")
	if bone < 0:
		return 0.0
	return skeleton.get_bone_global_pose(bone).origin.y \
		- skeleton.get_bone_global_rest(bone).origin.y
