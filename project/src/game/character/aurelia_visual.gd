extends Node3D
## Karakter Aurelia ("Avatar_Boy_Pole_Lohen") yang digerakkan pustaka animasi UAL.
##
## Susunannya:
##
##   Visual (node ini)
##   ├── UAL rig (umpan balik)   <- klip UAL diputar di sini, TIDAK digambar
##   │   ├── AnimationPlayer     : 85 klip (UAL1 + UAL2)
##   │   ├── Skeleton3D sumber   : tulang gaya Unreal (spine_01, thigh_l, ...)
##   │   ├── CastLayer           : lapisan tubuh atas, diproses lebih dulu
##   │   └── Retarget            : salin pose sumber -> tulang avatar (anak ke-2,
##   │                             jadi pose cast ikut tersalin)
##   └── Avatar (FBX)            <- yang terlihat: 209 tulang Biped
##       └── Skeleton3D avatar
##           └── ClothDynamics   : goyangan rambut/rok/syal (verlet)
##
## Kenapa animasi tidak langsung diputar di tulang avatar: klip UAL menyebut
## tulang milik rig mannequin, dan sumbu/rest pose Biped berbeda. Menyalin pose
## (bukan menulis ulang klip) berarti SEMUA 85 klip langsung jalan di avatar,
## termasuk combo serangan, casting, dan lompat.
##
## Kesetaraan: seluruh API mannequin.gd dipertahankan (set_locomotion,
## play_action, foot_pose, metrics, ...) supaya pemain, HUD, tapak api, dan tes
## tidak perlu diubah.

signal clip_changed(clip: String)

enum Mode { LOCOMOTION, ACTION, SHOWCASE, HELD }

const MODEL = preload("res://assets/mannequin/UAL1_Standard.glb")
const COMBAT_MODEL = preload("res://assets/combat/UAL2_Standard.glb")
const AVATAR = preload("res://assets/aurelia/Avatar_Boy_Pole_Lohen.fbx")
const Materials = preload("res://src/game/character/aurelia_materials.gd")
const Retarget = preload("res://src/game/animation/retarget_modifier.gd")
const ClothDynamics = preload("res://src/game/animation/cloth_dynamics.gd")
const Humanoid = preload("res://src/game/animation/humanoid_map.gd")
const CastLayer = preload("res://src/game/animation/cast_layer.gd")
const Catalog = preload("res://src/game/animation/catalog.gd")
const Metrics = preload("res://src/game/animation/anim_metrics.gd")

const IDLE := "Idle_Loop"
const AIR_CLIP := "Jump_Loop"
const COMBAT_LIBRARY := "ual2"
const FADE := 0.18
## Pemulihan setelah mendarat: klip mendarat hanya dipakai sesaat, lalu badan
## kembali ke gait supaya tidak terasa berhenti mendadak.
const LAND_RECOVERY := 0.28
const OFFSET_SPEED := 6.0
## Dua iterasi cukup untuk kain panjang; empat terlalu mahal untuk HP.
const CLOTH_ITERATIONS := 2
## Kecepatan avatar "ditanam" ke tanah (1/detik).
const PLANT_SPEED := 5.0

var animation: AnimationPlayer
var skeleton: Skeleton3D
## Avatar bisa punya lebih dari satu kerangka: importer FBX memecah berkas
## menjadi satu Skeleton3D per kelompok kulit (badan, rambut, mata) kalau
## himpunan tulangnya tidak bersambung. Semuanya harus didorong retarget, dan
## tulang kain di kerangka mana pun harus ikut bergoyang.
var avatars: Array[Skeleton3D] = []
var retargets: Array[Retarget] = []
var cloths: Array[ClothDynamics] = []
## Kerangka utama (tulang terbanyak) = badan yang dipakai efek kaki dan tes.
var avatar: Skeleton3D
var retarget: Retarget
var cloth: ClothDynamics
var cast_layer: CastLayer
var metrics: Dictionary = {}
var mode := Mode.LOCOMOTION
var clip := IDLE
var gait := IDLE
var ground_offset := 0.0
## Geser turun tambahan supaya telapak menyentuh tanah (lihat _physics_process).
var plant_offset := 0.0
var playback_scale := 1.0
## Node rig UAL (alat umpan balik animasi, disembunyikan) dan node avatar FBX.
var rig_model: Node3D
var avatar_root: Node3D
## Ringkasan keadaan rig (tulang terpetakan, rantai kain) untuk log dan tes.
var status := ""
var _model: Node3D
var _avatar_root: Node3D
var _hold_after := false
var _action_left := 0.0
var _library: AnimationLibrary


func _ready() -> void:
	_build_source()
	if animation == null or skeleton == null:
		return
	animation.animation_finished.connect(_on_animation_finished)
	_merge_combat_library()
	_configure_clips()
	# CastLayer dulu, Retarget sesudah: urutan anak = urutan proses modifier.
	_setup_cast_layer()
	_build_avatar()
	metrics = Metrics.measure_catalog(animation, skeleton, Catalog)
	animation.play(Catalog.play_name(IDLE), 0.0)
	animation.advance(0.0)
	print("[aurelia] %d klip, %d metrik terukur, %d tulang avatar" % [
		animation.get_animation_list().size(), metrics.size(), avatar.get_bone_count()])
	print(status)


func _build_source() -> void:
	var model: Node3D = MODEL.instantiate()
	# Koreksi arah model (menghadap -Z Godot). Avatar memakai koreksi yang sama
	# supaya wajah keduanya menghadap arah yang sama.
	model.rotation.y = PI
	# Rig ini hanya alat umpan balik animasi: tulangnya yang penting, badannya
	# tidak boleh ikut tergambar di samping avatar.
	model.visible = false
	add_child(model)
	_model = model
	rig_model = model
	animation = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if animation == null or skeleton == null:
		push_error("Aurelia: AnimationPlayer/Skeleton3D sumber hilang")


func _merge_combat_library() -> void:
	# UAL2 punya tulang, rest pose, dan mesh yang sama; pustakanya dipindah ke
	# AnimationPlayer utama supaya semua klip berbagi satu clock animasi.
	var source: Node3D = COMBAT_MODEL.instantiate()
	var source_player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if source_player == null:
		push_error("Aurelia: UAL2 tidak punya AnimationPlayer")
		source.free()
		return
	_library = source_player.get_animation_library("")
	if _library == null:
		push_error("Aurelia: pustaka UAL2 kosong")
		source.free()
		return
	animation.add_animation_library(COMBAT_LIBRARY, _library)
	source.free()


func _build_avatar() -> void:
	var root: Node3D = AVATAR.instantiate()
	root.rotation.y = PI
	add_child(root)
	_avatar_root = root
	avatar_root = root
	for node in root.find_children("*", "Skeleton3D", true, false):
		avatars.append(node as Skeleton3D)
	if avatars.is_empty():
		push_error("Aurelia: Skeleton3D avatar tidak ditemukan di FBX")
		return
	# Kerangka dengan tulang terbanyak = badan; sisanya (rambut/mata) menyusul.
	avatars.sort_custom(func(a: Skeleton3D, b: Skeleton3D) -> bool:
		return a.get_bone_count() > b.get_bone_count())
	avatar = avatars[0]
	var meshes := Materials.apply(root)
	for index in range(avatars.size()):
		var target := avatars[index]
		var follower: Retarget = Retarget.new()
		follower.name = "Retarget%d" % index
		skeleton.add_child(follower)
		follower.configure(skeleton, target)
		retargets.append(follower)
		var springs: ClothDynamics = ClothDynamics.new()
		springs.name = "Cloth%d" % index
		target.add_child(springs)
		springs.configure(target, CLOTH_ITERATIONS)
		# Efek tapak api memakai tinggi tulang telapak avatar, bukan mannequin.
		springs.set_ground_height(0.0)
		cloths.append(springs)
	retarget = retargets[0]
	cloth = cloths[0]
	_describe_rig()
	print("[aurelia] %d mesh diberi material, %d kerangka (%s)" % [meshes,
		avatars.size(), _skeleton_summary()])


func _skeleton_summary() -> String:
	var parts := PackedStringArray()
	for index in range(avatars.size()):
		parts.append("%d:%d tulang" % [index, avatars[index].get_bone_count()])
	return ", ".join(parts)


func _configure_clips() -> void:
	for entry in Catalog.entries():
		var name: String = entry["name"]
		var play_name: String = Catalog.play_name(name)
		if not animation.has_animation(play_name):
			push_error("Aurelia: klip hilang dari berkas: " + play_name)
			continue
		var source := animation.get_animation(play_name)
		source.loop_mode = Animation.LOOP_LINEAR if Catalog.is_loop(name) \
			else Animation.LOOP_NONE


func _setup_cast_layer() -> void:
	if not animation.has_animation(CastLayer.CLIP):
		push_error("Aurelia: klip casting hilang")
		return
	cast_layer = CastLayer.new()
	cast_layer.name = "UpperBodyCast"
	skeleton.add_child(cast_layer)
	cast_layer.configure(animation.get_animation(CastLayer.CLIP))
	if cast_layer.tracks.is_empty():
		push_error("Aurelia: filter tulang casting kosong")


# ------------------------------------------------------------- lokomosi ----

func natural_speed(name: String) -> float:
	var measured: Dictionary = metrics.get(name, {})
	var speed := float(measured.get("natural_speed", 0.0))
	return speed if speed > 0.05 else 1.0


func set_locomotion(name: String, playback_speed := 1.0) -> void:
	if mode != Mode.LOCOMOTION:
		# Klip pilihan panel atau aksi sekali jalan tidak boleh ditimpa pemain.
		gait = name
		return
	gait = name
	mode = Mode.LOCOMOTION
	if name != clip:
		_play(name, FADE, playback_speed)
	else:
		animation.speed_scale = clampf(playback_speed, 0.1, 3.0)


func set_air_clip(name: String, playback_speed := 1.0) -> void:
	# Klip udara dipilih pemain (lompat), bukan dari band kecepatan.
	mode = Mode.LOCOMOTION
	gait = name
	if name != clip:
		_play(name, 0.1, playback_speed)
	else:
		animation.speed_scale = clampf(playback_speed, 0.1, 3.0)


func play_action(name: String) -> float:
	var measured: Dictionary = metrics.get(name, {})
	var length := float(measured.get("length", 0.0))
	if length <= 0.0 or not animation.has_animation(Catalog.play_name(name)):
		return 0.0
	_hold_after = Catalog.holds_last_frame(name)
	mode = Mode.ACTION
	_action_left = length
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
	_play(gait, 0.24, 1.0)


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


func clip_length() -> float:
	if animation == null:
		return 0.0
	return animation.current_animation_length


func progress() -> float:
	var length := clip_length()
	if length <= 0.0:
		return 0.0
	return clampf(animation.current_animation_position / length, 0.0, 1.0)


func is_busy() -> bool:
	return mode == Mode.ACTION or mode == Mode.SHOWCASE


## Dipakai panel grafik "Mode ringan": kain/rambut tetap bergoyang, tapi dengan
## penjaga bentuk satu iterasi sehingga biaya CPU-nya turun.
func set_light_cloth(light: bool) -> void:
	for wrapper in cloths:
		if wrapper != null:
			wrapper.set_quality(light)


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
	# Offset tanah halus: klip rendah (guling, meluncur) tidak menenggelamkan kaki.
	var measured: Dictionary = metrics.get(clip, {})
	var target := float(measured.get("ground_offset", 0.0))
	ground_offset = lerpf(ground_offset, target, 1.0 - exp(-OFFSET_SPEED * delta))
	_update_plant(delta)
	if _model != null:
		_model.position.y = ground_offset + plant_offset
	if _avatar_root != null:
		_avatar_root.position.y = ground_offset + plant_offset


## Tanam kaki. Kaki avatar 4 % lebih pendek daripada mannequin UAL, dan retarget
## memindahkan BENTUK pose, jadi di klip lokomosi telapak berhenti beberapa senti
## di atas tanah (dan efek tapak api tidak pernah melihat kontak). Selama badan
## menapak tanah, avatar diturunkan sampai telapak terendah kembali setinggi rest
## pose-nya. Di udara tidak diapa-apakan (badan memang harus terangkat).
func _update_plant(delta: float) -> void:
	var target := 0.0
	var body := get_parent()
	if body is CharacterBody3D and (body as CharacterBody3D).is_on_floor():
		var lowest := minf(foot_stride_lift(true), foot_stride_lift(false))
		target = clampf(-lowest, -0.06, 0.12)
	# Turun lebih cepat daripada naik: saat telapak menyentuh tanah (lift anjlok
	# sekejap) badan harus sudah turun, sedangkan saat naik cukup halus supaya
	# tidak terlihat menyentak.
	var speed := PLANT_SPEED if target > plant_offset else PLANT_SPEED * 4.0
	plant_offset = lerpf(plant_offset, target, 1.0 - exp(-speed * delta))


# --------------------------------------------- kontak kaki untuk efek api ----

func foot_pose(left: bool) -> Transform3D:
	# Dipakai tapak api: harus dari telapak yang BENAR-BENAR digambar (avatar),
	# bukan rig animasi yang tidak terlihat.
	var foot := Humanoid.find_bone(avatar, "Bip001 L Foot" if left else "Bip001 R Foot")
	if foot < 0 or avatar == null:
		return global_transform
	return avatar.global_transform * avatar.get_bone_global_pose(foot)


## Tinggi tulang telapak (pergelangan) di atas titik asal model, di RUANG DUNIA.
## Dipakai sebagai tebal telapak oleh efek tapak api, yang mengukur jarak dunia —
## jadi angkanya harus ikut skala model kalau importer FBX menskalakannya.
func foot_clearance(left: bool) -> float:
	var foot := Humanoid.find_bone(avatar, "Bip001 L Foot" if left else "Bip001 R Foot")
	if foot < 0 or avatar == null:
		return 0.1
	var rest := avatar.global_transform * avatar.get_bone_global_rest(foot)
	var base := avatar.global_transform.origin.y
	return clampf(rest.origin.y - base, 0.03, 0.2)


## Seberapa tinggi telapak terangkat dari tinggi rest-nya (untuk gerbang fase
## tumpuan di efek tapak api), juga di RUANG DUNIA supaya skalanya sepadan.
func foot_stride_lift(left: bool) -> float:
	var foot := Humanoid.find_bone(avatar, "Bip001 L Foot" if left else "Bip001 R Foot")
	if foot < 0 or avatar == null:
		return 0.0
	var rest := avatar.global_transform * avatar.get_bone_global_rest(foot)
	var now := avatar.global_transform * avatar.get_bone_global_pose(foot)
	return now.origin.y - rest.origin.y


# ---------------------------------------------------------------- tambahan ----

## Isi `status` dengan ringkasan rig; dipanggil sekali setelah avatar siap.
func _describe_rig() -> void:
	var parts := PackedStringArray()
	var chains := 0
	var bones := 0
	for index in range(retargets.size()):
		parts.append("kerangka %d: %s" % [index, retargets[index].report()])
	for springs in cloths:
		if springs.springs == null:
			continue
		parts.append(springs.diagnostics())
		parts.append("[cloth] grup: " + springs.springs.group_report())
		chains += springs.springs.chain_count()
		bones += springs.springs.bone_count()
	parts.append("[cloth] total: %d rantai, %d tulang" % [chains, bones])
	parts.append("[cloth] nama tulang mirip kain: " + _cloth_bone_sample())
	status = "\n".join(parts)


## Daftar tulang avatar yang namanya mengandung kain/rambut — dipakai untuk
## memastikan peta grup cocok dengan nama asli dari importer FBX.
func _cloth_bone_sample() -> String:
	var found := PackedStringArray()
	for springs in cloths:
		if springs.springs == null:
			continue
		found.append_array(springs.springs.bone_name_sample(24))
	return ", ".join(found) if not found.is_empty() else "(tidak ada)"
