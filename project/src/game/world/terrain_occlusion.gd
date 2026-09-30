extends RefCounted
## Conservative horizontal patches entirely INSIDE the terrain, never spanning valleys.

const Island = preload("res://src/game/island.gd")
const PATCH := 20.0


static func build(island: Island) -> OccluderInstance3D:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for z in range(-500, 500, int(PATCH)):
		for x in range(-500, 500, int(PATCH)):
			var floor_y := INF
			# Every original grid vertex in the patch; terrain triangles are linear.
			for dz in range(0, int(PATCH) + 1, int(Island.STEP)):
				for dx in range(0, int(PATCH) + 1, int(Island.STEP)):
					floor_y = minf(floor_y, island.surface_height(x + dx, z + dz))
			if floor_y < 2:
				continue
			floor_y -= 0.5
			var base := vertices.size()
			vertices.append_array(PackedVector3Array([Vector3(x, floor_y, z),
				Vector3(x + PATCH, floor_y, z), Vector3(x, floor_y, z + PATCH),
				Vector3(x + PATCH, floor_y, z + PATCH)]))
			for index in [0, 1, 2, 1, 3, 2]:
				indices.append(base + index)
	var shape := ArrayOccluder3D.new()
	shape.set_arrays(vertices, indices)
	var occluder := OccluderInstance3D.new()
	occluder.name = "TerrainOcclusion"
	occluder.occluder = shape
	island.add_child(occluder)
	return occluder
