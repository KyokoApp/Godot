extends Node3D
## Water is visual, not a walking floor. Terrain collision is carved to match.

const Shape = preload("res://src/game/water/water_shape.gd")
const WaterMaterial = preload("res://src/game/water/water_material.gd")
const TILE := 40
const STEP := 2.5
const MAX_TRIANGLES := 12000

var island: Node3D
var inland_material: ShaderMaterial
var ocean_material: ShaderMaterial
var triangle_count := 0


func _ready() -> void:
	name = "WaterSurfaces"
	inland_material = WaterMaterial.create()
	ocean_material = WaterMaterial.create(true)
	var sea := island.get_node("Sea") as MeshInstance3D
	sea.material_override = ocean_material
	sea.extra_cull_margin = 0.1
	for z in range(-120, 360, TILE):
		for x in range(0, 360, TILE):
			_build_tile(x, z)


func set_ssr(enabled: bool) -> void:
	inland_material.set_shader_parameter("ssr_enabled", enabled)
	# Deliberately keep wide ocean out of the ray-march budget.
	ocean_material.set_shader_parameter("ssr_enabled", false)


func _build_tile(start_x: int, start_z: int) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for row in range(int(TILE / STEP)):
		for column in range(int(TILE / STEP)):
			var x := start_x + column * STEP
			var z := start_z + row * STEP
			if Shape.distance_to_water(x + STEP * 0.5, z + STEP * 0.5) > 7.0:
				continue
			# Once below sea level the existing ocean supplies the same surface.
			if z >= 317.5:
				continue
			var base := vertices.size()
			for corner: Vector2 in [Vector2(0, 0), Vector2(STEP, 0),
					Vector2(0, STEP), Vector2(STEP, STEP)]:
				var px := x + corner.x
				var pz := z + corner.y
				vertices.append(Vector3(px - start_x, Shape.level(px, pz), pz - start_z))
				normals.append(Vector3.UP)
			for index in [0, 1, 2, 1, 3, 2]:
				indices.append(base + index)
	if vertices.is_empty():
		return
	triangle_count += indices.size() / 3
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var visual := MeshInstance3D.new()
	visual.name = "Water_%d_%d" % [start_x, start_z]
	visual.mesh = mesh
	visual.material_override = inland_material
	visual.position = Vector3(start_x, 0, start_z)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.extra_cull_margin = 0.1
	add_child(visual)
