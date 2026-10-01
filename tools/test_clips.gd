extends SceneTree
## Pastikan 85 klip katalog benar-benar ada di dalam dua berkas GLB.
## Nama hasil impor engine yang dipakai di sini, bukan nama di dalam JSON GLB.

const Catalog = preload("res://src/game/animation/catalog.gd")
# Kunci mengikuti nilai di katalog ("ual1"/"ual2", huruf kecil).
const MODELS := {
	"ual1": "res://assets/mannequin/UAL1_Standard.glb",
	"ual2": "res://assets/combat/UAL2_Standard.glb",
}
const EXPECTED_PER_FILE := 43

var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _clip_names(path: String) -> PackedStringArray:
	var scene: PackedScene = load(path)
	if scene == null:
		return PackedStringArray()
	var model: Node = scene.instantiate()
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var names := PackedStringArray()
	if player != null:
		names = player.get_animation_list()
	model.free()
	return names


func _run() -> void:
	var available: Dictionary = {}
	for source: String in MODELS:
		var names := _clip_names(MODELS[source])
		available[source] = names
		print("[clips-test] %s: %d klip" % [source, names.size()])
		_check(names.size() >= EXPECTED_PER_FILE,
			"%s hanya %d klip, minimal %d" % [source, names.size(), EXPECTED_PER_FILE])
	# Importer glTF membuang akhiran "_Loop" dari nama di AnimationPlayer, jadi yang
	# harus ada di sana adalah Catalog.play_name(), bukan nama mentah dari berkas GLB.
	var seen: Dictionary = {}
	for clip: String in Catalog.names():
		var entry: Dictionary = Catalog.find(clip)
		var source: String = entry["source"]
		var runtime: String = Catalog.play_name(clip).trim_prefix("ual2/")
		var names: PackedStringArray = available[source]
		if not names.has(runtime):
			_check(false, "klip hilang: %s (runtime %s) tidak ada di %s" % [
				clip, runtime, source])
			print("[clips-test] daftar ", source, ": ", ", ".join(names))
		if seen.has(Catalog.play_name(clip)):
			_check(false, "nama runtime bentrok: " + Catalog.play_name(clip))
		seen[Catalog.play_name(clip)] = clip
	print("[clips-test] katalog %d klip, gagal: %d" % [Catalog.clip_count(), _failures])
	if _failures == 0:
		print("[clips-test] HASIL: OK")
	quit(0 if _failures == 0 else 1)
