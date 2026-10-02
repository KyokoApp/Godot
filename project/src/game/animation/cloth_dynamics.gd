extends SkeletonModifier3D
## Goyangan kain & rambut yang ditempelkan ke tulang avatar.
##
## Modul ini hanya pembungkus tipis: seluruh perhitungan ada di
## cloth_springs.gd supaya bisa diuji tanpa pohon scene. Yang dikerjakan di sini
## adalah urutan eksekusi (Skeleton3D memanggil modifier SESUDAH animasi + retarget
## selesai, jadi tidak ada satu frame pun yang ketinggalan) dan pembagian waktu.
##
## Jatuh tempo: `_process_modification_with_delta` menerima delta dari Skeleton3D.
## Kalau engine memanggil tanpa delta (mis. saat editor menyimpan), dipakai delta
## fisika yang dikumpulkan di `_physics_process` supaya kecepatan tetap stabil.

const Springs = preload("res://src/game/animation/cloth_springs.gd")

var springs: Springs
var _skeleton: Skeleton3D
var _pending := 0.0
var _configured := false


func configure(skeleton: Skeleton3D, iterations := 2) -> void:
	_skeleton = skeleton
	springs = Springs.new()
	springs.configure(skeleton, iterations)
	_configured = true
	print(springs.render_diagnostics())
	print("[cloth] grup: ", springs.group_report())


func _physics_process(delta: float) -> void:
	_pending = minf(_pending + delta, Springs.MAX_DELTA * 2.0)


func _process_modification_with_delta(delta: float) -> void:
	if not _configured:
		return
	var dt := delta
	if dt <= 0.0:
		dt = _pending
	_pending = 0.0
	if dt <= 0.0:
		dt = 1.0 / 60.0
	springs.step(dt, _skeleton)


## Langkah pasti untuk tes headless: tidak bergantung urutan proses engine.
func simulate(delta: float) -> void:
	if _configured:
		springs.step(delta, _skeleton)


## Mode ringan: satu iterasi penjaga bentuk saja. Biaya kain turun hampir
## separuh, dan karena goyangan tetap dari verlet (bukan penjaga bentuk),
## gerakannya masih terlihat.
func set_quality(light: bool) -> void:
	if springs != null:
		springs.set_iterations(1 if light else Springs.DEFAULT_ITERATIONS)


func set_enabled(value: bool) -> void:
	if springs != null:
		springs.set_enabled(value)


func set_ground_height(value: float) -> void:
	if springs != null:
		springs.set_ground_height(value)


func set_wind(strength: float, direction: Vector3) -> void:
	if springs != null:
		springs.set_wind(strength, direction)


func diagnostics() -> String:
	return springs.render_diagnostics() if springs != null else "cloth: belum siap"
