extends SceneTree
## Tapak api 3D dari pose kaki mannequin: kontak berulang, tidak muncul saat
## diam/melayang, palet benar, dan kolam stamp tidak bocor.

const Character = preload("res://src/game/mannequin.gd")
const Trail = preload("res://src/game/foot_fire/foot_fire_trail.gd")
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
	var game := load("res://src/game/main.tscn").instantiate() as Node3D
	root.add_child(game)
	var trail: Trail = game.get("_foot_fire")
	var stick: Control = game.get("_joystick")
	var player: Node3D = game.get("_player")
	var character: Character = game.get("_visual")
	var ground: Node3D = game.get("_field")
	for frame in range(60):
		await physics_frame
		if player.is_on_floor():
			break
	_check(player.is_on_floor(), "Pemain tidak mendarat")
	var before := trail.emitted
	for frame in range(15):
		await physics_frame
	_check(trail.emitted == before, "Api muncul saat diam")
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	var lift_range := Vector2(INF, -INF)
	stick.set("direction", Vector2.UP)
	for frame in range(240):
		await physics_frame
		for side in range(2):
			var point := character.foot_pose(side == 0).origin
			var gap: float = point.y - ground.surface_height(point.x, point.z)
			minimum[side] = minf(minimum[side], gap)
			maximum[side] = maxf(maximum[side], gap)
		var lift := character.foot_stride_lift(true)
		lift_range.x = minf(lift_range.x, lift)
		lift_range.y = maxf(lift_range.y, lift)
	print("::notice::Foot contact min=", minimum, " max=", maximum,
		" rest=", character.foot_clearance(true), " swing=", lift_range,
		" stamps=", trail.emitted - before)
	_check(trail.emitted - before >= 3,
		"Kontak langkah berulang kurang: %d" % (trail.emitted - before))
	stick.set("direction", Vector2.ZERO)
	await physics_frame
	var count := trail.emitted
	for frame in range(100):
		await physics_frame
	_check(trail.emitted == count, "Api baru tetap muncul setelah berhenti")
	for stamp in trail.stamps:
		_check(not stamp.visible, "Api tidak habis sesuai lifetime")
	trail.set_physics_process(false)
	for index in range(40):
		trail.add_stamp(Transform3D(Basis.IDENTITY, Vector3(0, 6, 0)), index % 2 == 0)
	_check(trail.stamps.size() == Trail.MAX_STAMPS and trail.get_child_count() == 16,
		"Pool jejak kaki bocor")
	var material := trail.stamps[0].material_override as ShaderMaterial
	_check(material.get_shader_parameter("middle") == Trail.PALETTE[1],
		"Palet mannequin tidak terpasang")
	trail.set_physics_process(true)
	player.position.x += 50
	for frame in range(3):
		await physics_frame
	for stamp in trail.stamps:
		_check(not stamp.visible, "Clear teleport meninggalkan api")
	game.queue_free()
	for frame in range(4):
		await process_frame
