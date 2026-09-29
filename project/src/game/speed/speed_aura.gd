extends Node3D
## Smooth spatial energy ribbons + soft rim aura. No skeletons or character copies.

const Character = preload("res://src/game/mannequin.gd")
const SHADER = preload("res://src/game/speed/speed_aura.gdshader")
const WASH = preload("res://src/game/speed/speed_wash.gdshader")
const COLORS := {"miku": Color("409fff"), "kanna": Color("ff8a36"),
	"mannequin": Color("ae65ff")}
const POINTS := 24
const LANES := 6
var character: Character
var environment: Environment
var strength := 0.0
var tint := Color("409fff")
var paths: Array[Vector3] = []
var wash: ColorRect
var _ribbons: MeshInstance3D
var _shell: MeshInstance3D
var _mesh := ImmediateMesh.new()
var _material: ShaderMaterial
var _shell_material: ShaderMaterial
var _wash_material: ShaderMaterial
var _previous := Vector3.ZERO
var _skin := ""
var _time := 0.0
var _glow_before := false
var _glow_strength_before := 0.0
var _glow_threshold_before := 1.0


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_shell_material = _material.duplicate() as ShaderMaterial
	_shell_material.set_shader_parameter("shell", true)
	_ribbons = MeshInstance3D.new()
	_ribbons.mesh = _mesh
	_ribbons.material_override = _material
	_ribbons.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ribbons)
	_shell = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.57
	sphere.height = 1.8
	sphere.radial_segments = 24
	sphere.rings = 12
	_shell.mesh = sphere
	_shell.material_override = _shell_material
	_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shell)
	var layer := CanvasLayer.new()
	layer.layer = 0 # World wash below the existing HUD's layer 1.
	add_child(layer)
	wash = ColorRect.new()
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wash_material = ShaderMaterial.new()
	_wash_material.shader = WASH
	wash.material = _wash_material
	layer.add_child(wash)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if environment != null:
		_glow_before = environment.glow_enabled
		_glow_strength_before = environment.glow_strength
		_glow_threshold_before = environment.glow_hdr_threshold
	_previous = character.global_position
	clear()


func clear() -> void:
	paths.clear()
	strength = 0
	_mesh.clear_surfaces()
	_apply()


func update_motion(delta: float, speed: float, boosted: bool) -> void:
	var origin := character.global_position
	if origin.distance_to(_previous) > 3.0 or character.skin_id != _skin:
		clear()
	_previous = origin
	_skin = character.skin_id
	tint = COLORS.get(_skin, COLORS["mannequin"])
	_time += delta
	var target := 1.0 if boosted and speed > 0.3 else 0.0
	strength = lerpf(strength, target, 1.0 - exp(-delta * (8.0 if target > 0 else 11.0)))
	if strength < 0.003 and target == 0:
		clear()
		return
	# One sample per physics step, fixed-cost mesh budget even at high velocity.
	paths.push_front(origin + Vector3.UP * 0.9)
	if paths.size() > POINTS:
		paths.pop_back()
	_shell.global_position = origin + Vector3.UP * 0.9
	_draw_ribbons()
	_apply()


func _apply() -> void:
	var active := strength > 0.003
	_shell.visible = active
	_ribbons.visible = active
	wash.visible = active
	for material in [_material, _shell_material, _wash_material]:
		material.set_shader_parameter("strength", strength)
		material.set_shader_parameter("tint", tint)
	if environment != null:
		environment.glow_enabled = active or _glow_before
		environment.glow_strength = maxf(_glow_strength_before, strength * 0.85) if active \
			else _glow_strength_before
		environment.glow_hdr_threshold = 1.1 if active else _glow_threshold_before


func _draw_ribbons() -> void:
	_mesh.clear_surfaces()
	if paths.size() < 2:
		return
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera != null else paths[0] + Vector3(0, 2, 4)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for lane in range(LANES):
		for index in range(paths.size() - 1):
			var a := _point(index, lane)
			var b := _point(index + 1, lane)
			var direction := (b - a).normalized()
			var side := direction.cross((eye - a).normalized()).normalized() * 0.16
			if side.length_squared() < 0.00001:
				side = Vector3.RIGHT * 0.16
			var u := float(index) / (paths.size() - 1)
			var v := float(index + 1) / (paths.size() - 1)
			_vertex(a - side, Vector2(u, 0))
			_vertex(a + side, Vector2(u, 1))
			_vertex(b - side, Vector2(v, 0))
			_vertex(a + side, Vector2(u, 1))
			_vertex(b + side, Vector2(v, 1))
			_vertex(b - side, Vector2(v, 0))
	_mesh.surface_end()


func _point(index: int, lane: int) -> Vector3:
	var phase := lane * TAU / LANES + _time * 1.8 + index * 0.12
	var travel := paths[maxi(index - 1, 0)] - paths[mini(index + 1, paths.size() - 1)]
	var sideways := Vector3(-travel.z, 0, travel.x).normalized()
	if sideways.length_squared() < 0.001:
		sideways = Vector3.RIGHT
	return paths[index] + sideways * (cos(phase) * 0.46) + Vector3.UP * sin(phase) * 0.62


func _vertex(point: Vector3, uv: Vector2) -> void:
	_mesh.surface_set_uv(uv)
	_mesh.surface_set_normal(Vector3.UP)
	_mesh.surface_add_vertex(to_local(point))


func _exit_tree() -> void:
	if environment != null:
		environment.glow_enabled = _glow_before
		environment.glow_strength = _glow_strength_before
		environment.glow_hdr_threshold = _glow_threshold_before
