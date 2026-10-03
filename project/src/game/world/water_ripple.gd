extends Node3D
## Riak air di danau tengah: setiap kali kaki pemain menapak permukaan air,
## satu cincin riak lahir di situ, melebar dan meredam. Inilah yang membuat
## "jalan di atas air" TERASA — ada umpan balik visual di setiap langkah,
## bukan pemain yang melayang di atas bidang tak terlihat.
##
## Murah untuk HP: pool cincin dibuat sekali lalu dipakai ulang. Tanpa pool,
## tiap langkah membuat node baru dan runtime harus kerja sampah (turun FPS).
## Saat tidak ada yang berjalan di air, semua cincin tidur (visible = false)
## dan tidak memakai panggilan gambar sama sekali.

const Field = preload("res://src/game/world/field.gd")
const RIPPLE_SHADER = preload("res://src/game/world/water_ripple.gdshader")
## Cincin yang boleh hidup bersamaan. Dua langkah per detik dengan umur 1
## detik butuh 2 slot; 8 slot cukup bahkan saat lari + mendarat.
const POOL := 8
## Umur satu riak (detik) dan jarak terjauh cincin (meter).
const LIFE := 1.0
const MAX_RADIUS := 2.4
## Warna riak: biru dingin seperti cahaya bulan yang jatuh di air.
const TINT := Color(0.42, 0.70, 0.95)
## Setinggi di atas permukaan air cincin digambar. Gelombang danau bergerak
## +-0,04 m, jadi 0,05 m menaruh riak persis di puncak gelombang.
const LIFT := 0.05

var _slots: Array[MeshInstance3D] = []
var _age: PackedFloat32Array


func _ready() -> void:
	name = "WaterRipple"
	var quad := QuadMesh.new()
	quad.size = Vector2(MAX_RADIUS * 2.0, MAX_RADIUS * 2.0)
	_age.resize(POOL)
	for slot in range(POOL):
		_age[slot] = -1.0
		var material := ShaderMaterial.new()
		material.shader = RIPPLE_SHADER
		material.set_shader_parameter("tint", TINT)
		material.set_shader_parameter("life", LIFE)
		material.set_shader_parameter("radius", MAX_RADIUS)
		var ring := MeshInstance3D.new()
		ring.name = "Ripple_%d" % slot
		ring.mesh = quad
		ring.material_override = material
		# Cincin tidur mendatar tepat di atas permukaan air, di tengah danau.
		ring.position = Vector3(0.0, Field.POND_LEVEL + LIFT, 0.0)
		ring.rotation.x = -PI * 0.5
		ring.visible = false
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		_slots.append(ring)


## Lahirkan satu riak di titik `point` (titik kontak kaki). `power` 0..1:
## langkah pelan kecil, lari dan mendarat besar.
func spawn(point: Vector3, power := 1.0) -> void:
	var slot := _free_slot()
	if slot < 0:
		return
	var strength := clampf(power, 0.15, 1.0)
	_age[slot] = 0.0
	var ring := _slots[slot]
	# x/z dari titik tapak kaki, y dikunci ke garis air supaya riak tidak
	# pernah melayang di atas/bawah permukaan air karena tinggi badan.
	ring.position = Vector3(point.x, Field.POND_LEVEL + LIFT, point.z)
	var material := ring.material_override as ShaderMaterial
	material.set_shader_parameter("age", 0.0)
	material.set_shader_parameter("strength", 0.45 + 0.55 * strength)
	material.set_shader_parameter("radius", lerpf(1.2, MAX_RADIUS, strength))
	ring.visible = true


func _process(delta: float) -> void:
	for slot in range(POOL):
		if _age[slot] < 0.0:
			continue
		_age[slot] += delta
		if _age[slot] >= LIFE:
			_age[slot] = -1.0
			_slots[slot].visible = false
			continue
		var material := _slots[slot].material_override as ShaderMaterial
		material.set_shader_parameter("age", _age[slot])


## Slot bebas; kalau semuanya sedang hidup, pakai yang paling tua (paling
## hampang selesai) supaya riak baru tidak pernah hilang diam-diam.
func _free_slot() -> int:
	var oldest := -1
	var oldest_age := -1.0
	for slot in range(POOL):
		if _age[slot] < 0.0:
			return slot
		if _age[slot] > oldest_age:
			oldest_age = _age[slot]
			oldest = slot
	return oldest


## Jumlah cincin yang sedang hidup (dipakai log dan tes).
func active_count() -> int:
	var count := 0
	for slot in range(POOL):
		if _age[slot] >= 0.0:
			count += 1
	return count
