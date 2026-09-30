extends Node3D
## Archived stone model follows the approved winding dirt road; no new build UI.

const Island = preload("res://src/game/island.gd")
const Library = preload("res://src/game/world/nature_library.gd")
const SEGMENT := 24.0
var island: Island
var piece_count := 0


func _ready() -> void:
	var groups: Dictionary[int, Array] = {}
	var z := -310.0
	while z <= 310.0:
		var x := Island.road_x(z)
		var slope := (Island.road_x(z + 0.5) - Island.road_x(z - 0.5))
		var key := floori(z / SEGMENT)
		if not groups.has(key):
			groups[key] = []
		var origin := Vector3(Island.road_x(key * SEGMENT + SEGMENT * 0.5), 0,
			key * SEGMENT + SEGMENT * 0.5)
		var basis := Basis(Vector3.UP, atan2(slope, 1.0))
		basis = basis.scaled(Vector3(1.3, 0.18, 1.4))
		var dx := island.surface_height(x + 0.5, z) - island.surface_height(x - 0.5, z)
		var dz := island.surface_height(x, z + 0.5) - island.surface_height(x, z - 0.5)
		basis.x.y = dx * basis.x.x + dz * basis.x.z
		basis.z.y = dx * basis.z.x + dz * basis.z.z
		var position_3d := Vector3(x, island.surface_height(x, z) + 0.008, z)
		groups[key].append(Transform3D(basis, position_3d - origin))
		piece_count += 1
		z += 2.65 / sqrt(1.0 + slope * slope)
	for key in groups:
		var chunk := Node3D.new()
		chunk.position = Vector3(Island.road_x(key * SEGMENT + SEGMENT * 0.5), 0,
			key * SEGMENT + SEGMENT * 0.5)
		var placements: Array[Transform3D] = []
		placements.assign(groups[key])
		Library.add_batch(chunk, "RockPath_Round_Wide", placements, 72)
		add_child(chunk)
