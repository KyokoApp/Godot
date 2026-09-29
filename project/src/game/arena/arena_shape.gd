extends RefCounted
## Shared arena footprint for collision, vegetation and visual boundary.
const CENTER := Vector2(-145, 140)
const RADIUS := 42.0
const HEIGHT := 9.0


static func radius_at(angle: float) -> float:
	return RADIUS + 1.4 * sin(angle * 5) + 0.7 * cos(angle * 9)


static func distance_to(x: float, z: float) -> float:
	var point := Vector2(x, z) - CENTER
	return point.length() - radius_at(atan2(point.y, point.x))


static func carve(x: float, z: float, height: float) -> float:
	return lerpf(HEIGHT, height, smoothstep(0, 22, distance_to(x, z)))
