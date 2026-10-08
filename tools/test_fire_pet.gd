extends SceneTree

const Pet = preload("res://src/game/fire_pet.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _run() -> void:
	var scene: PackedScene = load("res://src/game/main.tscn")
	var game: Node3D = scene.instantiate()
	root.add_child(game)
	for frame in range(3):
		await physics_frame
	var pet: Pet = game.get("_pet")
	var spirit: Node3D = pet.get("_body")
	_check(spirit.name == "LegacyFireSpirit", "Visual pet lama belum dipasang")
	_check(spirit.get_node_or_null("FireCore") == null, "Inti bola padat masih dipakai")
	var tongues := spirit.get_node("FireTongues") as MeshInstance3D
	_check(tongues.mesh is QuadMesh, "Siluet lidah api belum dipasang")
	_check(tongues.mesh.size.y > tongues.mesh.size.x, "Api harus lebih tinggi daripada lebar")
	var flame_material := tongues.material_override as ShaderMaterial
	var outline: float = flame_material.get_shader_parameter("outline_pixels")
	_check(outline > 0 and outline <= 0.6, "Outline pet bukan subpixel tipis")
	var embers := spirit.get_node("SpiritEmbers") as GPUParticles3D
	_check(embers.amount == 5, "Budget percikan lama berubah")
	spirit.set("external_velocity", Vector3(5, 0, 0))
	spirit._process(0.1)
	var trail: Vector3 = spirit.get("_trail")
	_check(trail.x < 0 and trail.length() <= 0.20, "Api tidak mengikuti arah gerak")
	_check(pet.get_parent() == game, "Pet menempel pada rig, bukan node dunia")
	var delta := pet.global_position - pet.player.global_position
	_check(Vector2(delta.x, delta.z).length() >= 0.84, "Pet terlalu dekat dengan karakter")
	_check(delta.y > 0.3 and delta.y < 0.85, "Pet tidak sejajar bahu")
	var start := pet.global_position
	for frame in range(25):
		await physics_frame
	_check(pet.global_position.distance_to(start) > 0.005, "Pet tidak beranimasi melayang")
	var orbit: Node3D = game.get("_orbit")
	var catalog: Button = game.get("_catalog_button")
	var touch := InputEventScreenTouch.new()
	touch.index = 9
	touch.pressed = true
	touch.position = catalog.get_global_rect().get_center()
	orbit._input(touch)
	_check(orbit.get("_touches").is_empty(), "Katalog ikut memutar kamera")
	_check(pet.attack(), "Serangan pertama gagal")
	_check(not pet.attack(), "Cooldown tidak mencegah spam")
	_check(pet.casting and pet.projectiles.is_empty(), "Windup casting dilewati")
	for frame in range(12):
		await physics_frame
	_check(pet.projectiles.size() == 1, "Casting tidak melepas proyektil")
	var shot: CharacterBody3D = pet.projectiles[0]
	var wake := shot.get_node("FireWake") as GPUParticles3D
	_check(not wake.local_coords, "Ekor api harus tertinggal di dunia")
	_check(wake.amount == 4, "Budget ekor api ringan berubah")
	_check(shot.get_node_or_null("BoltSparks") == null,
		"Percikan berat masih menempel pada proyektil dasar")
	shot._process(0.05)
	var bolt_trail: Vector3 = shot.get("_trail")
	_check(bolt_trail.dot(shot.velocity) < 0 and bolt_trail.length() <= 0.901,
		"Selubung api tidak mengikuti arah proyektil")
	var vertical := shot.velocity.y
	await physics_frame
	await physics_frame
	_check(shot.velocity.y < vertical, "Proyektil tidak dipengaruhi gravitasi")
	var saw_finished := false
	for frame in range(240):
		await physics_frame
		if is_instance_valid(shot):
			saw_finished = saw_finished or shot.finished
		pet._prune()
		if saw_finished and pet.projectiles.is_empty():
			break
	_check(saw_finished, "Proyektil tidak berakhir setelah lintasannya")
	_check(pet.projectiles.is_empty(), "Proyektil tidak dibersihkan")
	_check(Pet.RAPID_FIRE_MAX_PROJECTILES == 10,
		"Batas auto-fire/volley tidak dijaga tetap ringan")
	for index in range(4):
		pet.cooldown = 0
		pet.attack()
		for frame in range(12):
			await physics_frame
	_check(pet.projectiles.size() <= Pet.MAX_PROJECTILES, "Batas proyektil terlampaui")
	await _test_fx_lifecycle(game, pet)
	print("[fire-pet-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)


func _test_fx_lifecycle(game: Node3D, pet: Pet) -> void:
	# Hit biasa tidak menambah ledakan/partikel/lampu; AoE skill punya jalur VFX
	# sendiri di SurvivalBuffSystem dan tidak lewat handler impact projectile.
	var children_before := game.get_child_count()
	pet._on_impact(pet.global_position, Vector3.UP)
	_check(game.get_child_count() == children_before,
		"Impact tembakan dasar masih membuat node ledakan")
	var expired := Pet.Projectile.new()
	expired.position = Vector3(0, 500, 0)
	game.add_child(expired)
	expired.set_physics_process(false)
	expired.age = Pet.Projectile.MAX_LIFETIME
	expired._physics_process(0.02)
	_check(expired.finished and expired.collision_layer == 0, "Peluru tamat masih aktif")
	_check(not expired.get_node("BoltCore").visible, "Inti tidak hilang saat impact")
	_check(not expired.get_node("FireWake").emitting, "Emitter tidak berhenti setelah tamat")
	_check(expired.get_node_or_null("BoltSparks") == null,
		"Emitter percikan dasar belum dihapus")
	_check(not expired.is_queued_for_deletion(), "Ekor api dipotong langsung")
	expired._physics_process(Pet.Projectile.TAIL_LIFETIME + 0.01)
	_check(expired.is_queued_for_deletion(), "Ekor api bocor setelah TTL")
	for frame in range(140):
		await physics_frame
	pet._prune()
	_check(pet.projectiles.is_empty(), "Peluru lama tertahan di daftar projectile")
