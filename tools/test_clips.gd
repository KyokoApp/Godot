extends SceneTree
## Pastikan 85 klip katalog benar-benar ada di dalam dua berkas GLB.
## Nama hasil impor engine yang dipakai di sini, bukan nama di dalam JSON GLB.

const Catalog = preload("res://src/game/animation/catalog.gd")
const MODELS := {
	"UAL1": "res://assets/mannequin/UAL1_Standard.glb",
	"UAL2": "res://assets/combat/UAL2_Standard.glb",
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
	for clip: String in Catalog.names():
		var entry: Dictionary = Catalog.find(clip)
		var source: String = entry["source"]
		var names: PackedStringArray = available[source]
		if names.has(clip):
			continue
		_check(false, "klip hilang: %s tidak ada di %s" % [clip, source])
		print("[clips-test] daftar ", source, ": ", ", ".join(names))
	print("[clips-test] katalog %d klip, gagal: %d" % [Catalog.clip_count(), _failures])
	if _failures == 0:
		print("[clips-test] HASIL: OK")
	quit(0 if _failures == 0 else 1)
