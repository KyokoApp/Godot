extends RefCounted
## Mengukur metrik tiap klip LANGSUNG dari tulang kaki, bukan dari tebakan:
##
##  - stride        : jarak maju-mundur satu kaki dalam satu siklus (meter)
##  - natural_speed : kecepatan gerak yang sebenarnya diwakili siklus itu (m/s)
##  - foot_min_y    : titik terendah tulang kaki selama klip
##  - ground_offset : koreksi naik supaya kaki tidak tenggelam ke tanah
##                    (termasuk tebal sol, lihat SOLE)
##
## Semua klip UAL dimainkan di tempat (root tidak bergerak), jadi satu-satunya
## cara jujur mencocokkan animasi dengan gerak badan adalah mengukur langkahnya
## lebih dulu lalu menyetel kecepatan main. Itulah yang menghilangkan kaki
## meluncur (foot sliding) yang sebelumnya terjadi.

const SAMPLE_RATE := 60.0
const IDLE_RATE := 20.0
const FOOT_LEFT := "foot_l"
const FOOT_RIGHT := "foot_r"
## Batas koreksi naik. Dinaikkan dari 0,25: klip jongkok/meluncur membuat kaki
## turun jauh lebih dari 25 cm, dan kalau koreksinya dipotong di sana kakinya
## tetap tenggelam.
const MAX_OFFSET := 0.45
## Tebal sol kaki. Tulang foot_l/foot_r ada di ATAS permukaan sol, jadi kalau
## kaki diposisikan tepat di titik tulang, solnya masih masuk beberapa sentimeter
## ke tanah. Inilah sisa "kaki tenggelam sedikit" yang terlihat saat jalan dan
## jongkok. Angkanya diukur kasar dari bentuk mesh UAL (pergelangan ke ujung kaki).
const SOLE := 0.035


static func measure(player: AnimationPlayer, skeleton: Skeleton3D, clip: String,
		rate := SAMPLE_RATE) -> Dictionary:
	var result := {"length": 0.0, "stride": 0.0, "natural_speed": 0.0,
		"foot_min_y": 0.0, "samples": 0}
	if player == null or skeleton == null or clip.is_empty():
		return result
	if not player.has_animation(clip):
		return result
	var animation := player.get_animation(clip)
	result["length"] = animation.length
	var left := skeleton.find_bone(FOOT_LEFT)
	var right := skeleton.find_bone(FOOT_RIGHT)
	if left < 0 or right < 0 or animation.length <= 0.0:
		return result
	player.play(clip, 0.0)
	player.advance(0.0)
	var min_y := INF
	var samples := 0
	var min_z := Vector2(INF, INF)
	var max_z := Vector2(-INF, -INF)
	var steps := maxi(int(ceil(animation.length * rate)) + 1, 2)
	for _step in range(steps):
		var left_pose := skeleton.get_bone_global_pose(left).origin
		var right_pose := skeleton.get_bone_global_pose(right).origin
		min_y = minf(min_y, minf(left_pose.y, right_pose.y))
		min_z.x = minf(min_z.x, left_pose.z)
		max_z.x = maxf(max_z.x, left_pose.z)
		min_z.y = minf(min_z.y, right_pose.z)
		max_z.y = maxf(max_z.y, right_pose.z)
		player.advance(1.0 / rate)
		samples += 1
	result["samples"] = samples
	var stride := ((max_z.x - min_z.x) + (max_z.y - min_z.y)) * 0.5
	result["stride"] = stride
	result["foot_min_y"] = min_y if min_y < INF else 0.0
	# Satu siklus langkah = dua langkah kaki, jadi kecepatan alami = 2 × stride / durasi.
	result["natural_speed"] = 2.0 * stride / animation.length
	return result


static func measure_catalog(player: AnimationPlayer, skeleton: Skeleton3D,
		catalog: GDScript) -> Dictionary:
	# Mengembalikan { clip: metrik } untuk SELURUH katalog, plus offset tanah
	# relatif terhadap pose berdiri (Idle_Loop).
	var metrics: Dictionary = {}
	var baseline := INF
	for entry in catalog.entries():
		var name: String = entry["name"]
		# Klip langkah diukur rapat (butuh stride), sisanya cukup untuk titik kaki.
		var rate := SAMPLE_RATE if catalog.is_gait(name) else IDLE_RATE
		var measured := measure(player, skeleton, catalog.play_name(name), rate)
		measured["source_name"] = catalog.play_name(name)
		metrics[name] = measured
		if name == "Idle_Loop" and measured["foot_min_y"] < INF:
			baseline = measured["foot_min_y"]
	if baseline == INF:
		baseline = 0.0
	for name: String in metrics:
		var measured: Dictionary = metrics[name]
		measured["ground_offset"] = 0.0
		if measured["foot_min_y"] < INF:
			var drop := baseline - float(measured["foot_min_y"]) + SOLE
			measured["ground_offset"] = clampf(drop, 0.0, MAX_OFFSET)
	return metrics


static func report(metrics: Dictionary, catalog: GDScript) -> String:
	var lines := PackedStringArray()
	for entry in catalog.entries():
		var name: String = entry["name"]
		if not metrics.has(name):
			continue
		var measured: Dictionary = metrics[name]
		lines.append("%s: %.2fs stride %.2fm alami %.2f m/s offset %.3fm" % [
			name, measured["length"], measured["stride"],
			measured["natural_speed"], measured["ground_offset"]])
	return "\n".join(lines)
