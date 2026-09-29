extends SceneTree

const Character = preload("res://src/game/mannequin.gd")
const Trail = preload("res://src/game/foot_fire/foot_fire_trail.gd")
const Hair = preload("res://src/game/animation/hair_spring.gd")
var _failures := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
		print("::error::", message)


func _run() -> void:
	var character := Character.new()
	root.add_child(character)
	character.set_skin(Character.MIKU)
	var hair := character.hair
	_check(hair.bones.size() == 16, "Budget/tulang twintail berubah")
	hair.active = false
	for frame in range(120):
		hair.simulate(1.0 / 60.0, Vector3(0, 0, -5), Vector3.ZERO, 2)
	_check(hair.angles[0].length() > 0.02, "Rambut tidak merespons gerak")
	_check(not hair.angles[0].is_equal_approx(hair.angles[7]), "Rambut bukan chain bertahap")
	for angle in hair.angles:
		_check(angle.is_finite() and angle.length() <= Hair.MAX_ANGLE + 0.0001,
			"Spring rambut tidak dibatasi")
	for frame in range(360):
		hair.simulate(1.0 / 60.0, Vector3.ZERO, Vector3.ZERO, 0)
	for angle in hair.angles:
		_check(angle.length() < 0.003, "Rambut tidak berhenti berayun")
	hair.reset_motion()
	_check(hair.angles[0] == Vector2.ZERO, "Reset teleport/switch tidak bersih")
	character.set_skin(Character.KANNA)
	_check(not hair.active, "Rambut Miku masih aktif saat tersembunyi")
	for skin in [Character.MIKU, Character.KANNA, Character.MANNEQUIN]:
		character.set_skin(skin)
		for left in [true, false]:
			var pose := character.foot_pose(left)
			_check(pose.origin.is_finite() and pose.basis.is_finite(), "Foot binding tidak valid")
			_check(character.foot_clearance(left) > 0.05, "Sole clearance tidak valid")
	character.queue_free()
	await process_frame
	await _test_contacts()
	print("[motion-flair-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)


func _test_contacts() -> void:
	var scene: PackedScene = load("res://src/game/main.tscn")
	var game := scene.instantiate() as Node3D
	root.add_child(game)
	var trail: Trail = game.get("_foot_fire")
	var stick: Control = game.get("_joystick")
	var player: Node3D = game.get("_player")
	var character: Character = game.get("_visual")
	var start := player.position
	for skin in [Character.MANNEQUIN, Character.MIKU, Character.KANNA]:
		character.set_skin(skin)
		player.position = start
		for frame in range(30):
			await physics_frame
		var before := trail.emitted
		for frame in range(15):
			await physics_frame
		_check(trail.emitted == before, "Api muncul saat diam: " + skin)
		var minimum := Vector2(INF, INF)
		var maximum := Vector2(-INF, -INF)
		var lift_range := Vector2(INF, -INF)
		var island: Node3D = game.get("_island")
		stick.set("direction", Vector2.UP)
		for frame in range(180):
			await physics_frame
			for side in range(2):
				var point := character.foot_pose(side == 0).origin
				var gap: float = point.y - island.surface_height(point.x, point.z)
				minimum[side] = minf(minimum[side], gap)
				maximum[side] = maxf(maximum[side], gap)
			var lift := character.foot_stride_lift(true)
			lift_range.x = minf(lift_range.x, lift)
			lift_range.y = maxf(lift_range.y, lift)
		print("::notice::Foot contact ", skin, " min=", minimum, " max=", maximum,
			" rest=", character.foot_clearance(true), " source swing=", lift_range,
			" stamps=", trail.emitted - before)
		_check(trail.emitted - before >= 5,
			"Kontak langkah %s berulang kurang: %d" % [skin, trail.emitted - before])
		print("[motion-flair-test] contacts ", skin, "=", trail.emitted - before)
		stick.set("direction", Vector2.ZERO)
		# Drain the already-started physics tick before measuring idle.
		await physics_frame
		var count := trail.emitted
		for frame in range(100):
			await physics_frame
		_check(trail.emitted == count, "Api baru tetap muncul setelah berhenti: " + skin)
	for stamp in trail.stamps:
		_check(not stamp.visible, "Api tidak habis sesuai lifetime")
	trail.set_physics_process(false)
	for index in range(40):
		trail.add_stamp(Transform3D(Basis.IDENTITY, Vector3(0, 6, 0)), "miku", index % 2 == 0)
	_check(trail.stamps.size() == Trail.MAX_STAMPS and trail.get_child_count() == 16,
		"Pool jejak kaki bocor")
	var material := trail.stamps[0].material_override as ShaderMaterial
	_check(material.get_shader_parameter("middle") == Trail.PALETTES["miku"][1],
		"Palet Miku tidak terpasang")
	trail.set_physics_process(true)
	player.position.x += 50
	for frame in range(3):
		await physics_frame
	for stamp in trail.stamps:
		_check(not stamp.visible, "Clear teleport meninggalkan api")
	game.queue_free()
	for frame in range(4):
		await process_frame
