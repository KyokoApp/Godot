extends Node
## Dua kontak per siklus animasi; gerak nyata + lantai mencegah langkah palsu.

const Field = preload("res://src/game/world/field.gd")
const WorldAudio = preload("res://src/game/audio/world_audio.gd")
const WaterRipple = preload("res://src/game/world/water_ripple.gd")
const Character = preload("res://src/game/mannequin.gd")
## Pita pasir di pantai (meter di atas permukaan air). Samakan dengan
## `shore_high` di ground.gdshader supaya suara dan warna bertemu di tempat yang
## sama. Dulu batasnya jarak dari pusat (padang 100 m); pulau 100 m berbentuk
## tidak beraturan, jadi yang dipakai adalah ketinggian tanah.
const SHORE_HEIGHT := 2.6

var audio: WorldAudio
var field: Field
var body: CharacterBody3D
var visual: Character
# Riak air di danau tengah; boleh null (misalnya di tes audio saja).
var ripples: WaterRipple
var emitted := 0
var _last_half := -1
var _last_clip := ""
var _air_time := 0.0
var _contact_cooldown := 0.0
var _left := false


func surface_at(point: Vector3, normal: Vector3) -> String:
	# Danau tengah: pemain berjalan DI ATAS air, jadi kakinya basah — bukan
	# bunyi rumput/darat. Dari sini juga riak tiap langkah lahir.
	if Field.is_water(point.x, point.z):
		# Puncak pulau batu tempat pintunya berdiri (0,5 m di atas air): di
		# situ langkahannya bunyi batu, bukan air. Titik kontak kaki selalu
		# setinggi tanah + 0,08 m, jadi batas 0,3 m memisahkan keduanya.
		if point.y >= Field.POND_LEVEL + 0.3:
			return "stone"
		return "water"
	# Pulau ini seluruhnya rumput; hanya pita pasir di garis air yang beda,
	# sama seperti pita pasir di ground.gdshader.
	if normal.y < 0.55:
		return "stone"
	if field != null and field.surface_height(point.x, point.z) < SHORE_HEIGHT:
		return "dirt"
	return "grass"


func update_motion(delta: float, speed: float) -> void:
	_contact_cooldown = maxf(0, _contact_cooldown - delta)
	if not body.is_on_floor():
		_air_time += delta
		_last_half = -1
		return
	var landed := _air_time > 0.18
	_air_time = 0
	if speed < 0.15 and not landed:
		_last_half = -1
		return
	var animation := visual.animation
	var length := animation.current_animation_length
	if length <= 0:
		return
	var half := int(animation.current_animation_position / length * 2.0)
	var clip := animation.current_animation
	var contact := half != _last_half or clip != _last_clip
	_last_half = half
	_last_clip = clip
	if (contact or landed) and _contact_cooldown <= 0:
		var point := body.global_position - Vector3(0, 0.82, 0)
		_left = not _left
		point += visual.global_basis.x * (0.13 if _left else -0.13)
		var surface := surface_at(point, body.get_floor_normal())
		# Air tidak punya bank suara sendiri: pakai sampel tanah (langkah
		# basah) supaya di danau tetap ada umpan balik bunyi.
		var bank := "dirt" if surface == "water" else surface
		audio.footstep(point, bank, speed, landed)
		if surface == "water" and ripples != null:
			# Riak mengikuti kerasnya langkah: jalan pelan kecil, lari besar,
			# dan mendarat (jatuh ke air) paling besar.
			var power := clampf(speed / 6.0, 0.15, 1.0)
			ripples.spawn(point, 1.0 if landed else power)
		emitted += 1
		_contact_cooldown = 0.12
