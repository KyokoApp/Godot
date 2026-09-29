extends SceneTree
## Simulasi gerak, pin, lantai, teleport dan batas kain; render diuji lewat test_grass.

const Character = preload("res://src/game/mannequin.gd")
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
	await process_frame
	var robe := character.robe
	_check(robe != null and robe.ready_to_wear, "Jubah tidak dapat dipasang pada rig")
	if robe == null or not robe.ready_to_wear:
		quit(1)
		return
	robe.set_physics_process(false)
	_check(robe.points.size() == 64, "Budget partikel kain berubah")
	var hidden := 0
	for node in character.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not robe.is_ancestor_of(mesh) and not mesh.visible:
			hidden += 1
	_check(hidden > 0, "Mesh sumber masih menembus pakaian")
	character.update_motion(5.0)
	var moved := false
	for frame in range(120):
		character.position.x += 0.045
		character.rotation.y += 0.01
		character.animation.advance(1.0 / 60.0)
		robe._physics_process(1.0 / 60.0)
		for index in range(robe.points.size()):
			var point: Vector3 = robe.points[index]
			_check(point.is_finite(), "Simulasi kain menghasilkan NaN")
			var target: Vector3 = robe._target(index / robe.SIDES, index % robe.SIDES)
			if index < robe.SIDES:
				_check(point.distance_to(target) < 0.001, "Pin pinggang terlepas")
			else:
				moved = moved or point.distance_to(target) > 0.015
				_check(point.distance_to(target) < 0.40, "Kain terbang di luar batas")
				_check(point.y >= character.global_position.y + 0.059, "Kain menembus lantai")
	_check(moved, "Rok kaku: tidak ada respons fisika")
	character.position += Vector3(30, 0, 15)
	robe._physics_process(1.0 / 60.0)
	_check(robe.points[0].distance_to(robe._target(0, 0)) < 0.001,
		"Teleport tidak mereset kain")
	# Prediksi collision kapsul sederhana, termasuk kasus tepat pada sumbu.
	var pushed: Vector3 = robe._outside_capsule(Vector3.ZERO, Vector3.ZERO, Vector3.UP, 0.2)
	_check(pushed.is_finite() and pushed.length() >= 0.199, "Collision kapsul gagal")
	print("[robe-test] HASIL: ", "OK" if _failures == 0 else "GAGAL")
	quit(0 if _failures == 0 else 1)
