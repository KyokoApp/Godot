extends Control
## Original north-up cartography. One cached texture, no extra 3D camera or viewport.
const Island = preload("res://src/game/island.gd")
const Shape = preload("res://src/game/arena/arena_shape.gd")
const Water = preload("res://src/game/water/water_shape.gd")
const SHADER = preload("res://src/game/ui/minimap.gdshader")
const DIAMETER := 176.0
const RADIUS := 80.0
const RANGE := 125.0
const RESOLUTION := 256
var island: Island
var player: Node3D
var facing: Node3D
var camera: Camera3D
var _map_material: ShaderMaterial
var _elapsed := 0.0
var _texture: ImageTexture


func _ready() -> void:
	name = "Minimap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(24, 24)
	size = Vector2.ONE * DIAMETER
	var image := Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGB8)
	for y in range(RESOLUTION):
		for x in range(RESOLUTION):
			var world := (Vector2(x, y) + Vector2.ONE * 0.5) / RESOLUTION * 1000.0
			world -= Vector2.ONE * 500.0
			image.set_pixel(x, y, terrain_color(world))
	_texture = ImageTexture.create_from_image(image)
	var map := TextureRect.new()
	map.texture = _texture
	map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map.position = Vector2.ONE * 8
	map.size = Vector2.ONE * RADIUS * 2
	_map_material = ShaderMaterial.new()
	_map_material.shader = SHADER
	_map_material.set_shader_parameter("span", RANGE * 2.0 / 1000.0)
	map.material = _map_material
	add_child(map)
	# Draw markers above the texture, never behind it.
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_markers.bind(overlay))
	add_child(overlay)
	_process(1.0)


func terrain_color(point: Vector2) -> Color:
	var height := island.surface_height(point.x, point.y)
	var water_level := maxf(0.0, Water.level(point.x, point.y)) \
		if Water.covers(point.x, point.y) else 0.0
	if height < water_level + 0.3:
		return Color("568c9c")
	if Shape.distance_to(point.x, point.y) <= 0:
		return Color("909c99")
	if Island.road_mask(point.x, point.y) > 0.4:
		return Color("d3c79c")
	if height < 1.8:
		return Color("b8ba91")
	return Color("638f78").lerp(Color("a5b18d"), clampf(height / 42.0, 0, 1))


func map_offset(point: Vector2) -> Vector2:
	return (point - Vector2(player.position.x, player.position.z)) * RADIUS / RANGE


func contains_point(point: Vector2) -> bool:
	var local := get_global_transform_with_canvas().affine_inverse() * point
	return local.distance_to(size * 0.5) <= DIAMETER * 0.5


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < 0.1 or not is_instance_valid(player):
		return
	_elapsed = 0.0
	_map_material.set_shader_parameter("center_uv",
		(Vector2(player.position.x, player.position.z) + Vector2.ONE * 500) / 1000.0)
	for child in get_children():
		if child is Control:
			child.queue_redraw()
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	draw_circle(center + Vector2(0, 3), 88, Color(0.015, 0.035, 0.05, 0.35))
	draw_arc(center, 84, 0, TAU, 96, Color(0.92, 0.95, 0.88, 0.85), 2, true)
	draw_arc(center, 87, 0, TAU, 96, Color(1, 1, 1, 0.22), 1, true)


func _draw_markers(canvas: Control) -> void:
	if not is_instance_valid(player):
		return
	var center := size * 0.5
	var arena := map_offset(Shape.CENTER)
	# Hide rather than invent off-map positions. The ring marks the real arena radius.
	if arena.length() + Shape.RADIUS * RADIUS / RANGE < RADIUS - 2:
		canvas.draw_arc(center + arena, Shape.RADIUS * RADIUS / RANGE,
			0, TAU, 64, Color(0.89, 0.91, 1, 0.85), 1.5, true)
	if is_instance_valid(camera):
		var forward := -camera.global_basis.z
		var angle := Vector2(forward.x, forward.z).angle()
		var cone := PackedVector2Array([center])
		for index in range(17):
			cone.append(center + Vector2.from_angle(angle - 0.55 + index * 1.1 / 16) * 35)
		canvas.draw_colored_polygon(cone, Color(0.8, 0.95, 1, 0.15))
	var yaw := facing.global_rotation.y if is_instance_valid(facing) else 0.0
	var arrow := PackedVector2Array()
	for point in [Vector2(0, -10), Vector2(7, 7), Vector2(0, 3), Vector2(-7, 7)]:
		arrow.append(center + point.rotated(-yaw))
	canvas.draw_circle(center, 12, Color(0.05, 0.18, 0.23, 0.6))
	canvas.draw_colored_polygon(arrow, Color("ebffff"))
	canvas.draw_string(ThemeDB.fallback_font, Vector2(center.x - 5, 6), "N",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f4f4de"))
