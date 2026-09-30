extends RefCounted
## Shared analytic watershed: lake with bays + a winding outlet to the southeast sea.

const LAKE_CENTER := Vector2(105, -50)
const LAKE_LEVEL := 4.5
const LAKE_AXES := Vector2(54, 38)
const RIVER_BEGIN := -55.0
const RIVER_END := 330.0


static func river_x(z: float) -> float:
	return 142.0 + 0.30 * (z + 40.0) + 22.0 * sin((z + 40.0) / 40.0)


static func river_slope(z: float) -> float:
	return 0.30 + 0.55 * cos((z + 40.0) / 40.0)


static func lake_distance(x: float, z: float) -> float:
	var point := (Vector2(x, z) - LAKE_CENTER) / LAKE_AXES
	var angle := atan2(point.y, point.x)
	var shore := 1.0 + 0.14 * sin(3.0 * angle) + 0.08 * sin(5.0 * angle)
	shore += 0.07 * cos(2.0 * angle)
	return (point.length() - shore) * LAKE_AXES.y


static func river_distance(x: float, z: float) -> float:
	var width := 9.0 + 2.0 * sin(z / 31.0) + 1.4 * cos(z / 17.0)
	var slope := river_slope(z)
	var distance := absf(x - river_x(z)) / sqrt(1.0 + slope * slope) - width
	return maxf(distance, maxf(RIVER_BEGIN - z, z - RIVER_END))


static func distance_to_water(x: float, z: float) -> float:
	if x < 15 or x > 340 or z < -125 or z > 355:
		return 1000.0
	return minf(lake_distance(x, z), river_distance(x, z))


static func level(_x: float, z: float) -> float:
	return LAKE_LEVEL * (1.0 - smoothstep(0.0, 320.0, z))


static func carve(x: float, z: float, original: float) -> float:
	var distance := distance_to_water(x, z)
	if distance >= 22:
		return original
	var bed := level(x, z) - 2.6 * (1.0 - smoothstep(-12.0, 1.5, distance))
	var influence := 1.0 - smoothstep(0.0, 22.0, distance)
	return minf(original, lerpf(original, bed, influence))


static func covers(x: float, z: float, margin := 0.0) -> bool:
	return distance_to_water(x, z) < 6.0 + margin
