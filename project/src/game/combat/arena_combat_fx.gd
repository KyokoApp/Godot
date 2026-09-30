extends Node3D
## Small, procedural anime-action combat effects; no added texture or model assets.

const Slash = preload("res://src/game/combat/arena_slash_fx.gd")
const Impact = preload("res://src/game/combat/arena_impact_fx.gd")

var camera: Camera3D


func play_swing(attacker: Vector3, target: Vector3, tint: Color,
		power: float = 1.0) -> void:
	var direction := target - attacker
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	var origin := attacker + Vector3.UP * 1.05 + direction * 0.42
	var effect: Node3D = Slash.new()
	add_child(effect)
	effect.call("configure", origin, _screen_facing(origin), tint, power)


func spawn_impact(point: Vector3, tint: Color, damage: int = 0,
		heavy: bool = false, label_text: String = "") -> void:
	var effect: Node3D = Impact.new()
	add_child(effect)
	effect.call("configure", point, _screen_facing(point), tint, damage, heavy, label_text)


func spawn_guard(point: Vector3, tint: Color, label_text: String = "PARRY") -> void:
	spawn_impact(point, tint, 0, false, label_text)


func spawn_dodge(position: Vector3, tint: Color) -> void:
	play_swing(position, position + Vector3.FORWARD, tint, 0.72)


func clear() -> void:
	for effect in get_children():
		effect.queue_free()


func _screen_facing(point: Vector3) -> Vector3:
	if is_instance_valid(camera):
		var direction := camera.global_position - point
		direction.y = 0.0
		if direction.length_squared() > 0.001:
			return direction.normalized()
	return Vector3.FORWARD
