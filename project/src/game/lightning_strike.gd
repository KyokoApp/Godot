extends Node3D
## Hantaman Petir: petir epic dari langit ala ulti Eudora.
## Beam vertikal + kilau area + shockwave, damage AoE 2.8 m, cooldown 1 dtk.

const LIFETIME := 0.75
const DAMAGE := 182
const RADIUS := 2.8
const HEIGHT := 18.0

var damage_value := DAMAGE
var radius_value := RADIUS

var _age := 0.0
var _beam: MeshInstance3D
var _core: MeshInstance3D
var _ring: MeshInstance3D
var _light: OmniLight3D
var _sparks: GPUParticles3D
var _flash: MeshInstance3D


func _ready() -> void:
	_build_beam()
	_build_ring()
	_build_light()
	_build_sparks()
	_build_flash()
	_apply_damage()
	var t := create_tween()
	t.tween_property(_light, "light_energy", 0.0, 0.35).set_delay(0.22)


func _build_beam() -> void:
	_beam = MeshInstance3D.new()
	_beam.name = "BoltBeam"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.08
	mesh.bottom_radius = 0.42
	mesh.height = HEIGHT
	mesh.radial_segments = 10
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	_beam.mesh = mesh
	_beam.position.y = HEIGHT * 0.5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.disable_receive_shadows = true
	mat.albedo_color = Color(0.62, 0.78, 1.0, 0.92)
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.65, 1.0)
	mat.emission_energy_multiplier = 3.2
	_beam.material_override = mat
	add_child(_beam)
	_core = MeshInstance3D.new()
	_core.name = "BoltCore"
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 0.03
	core_mesh.bottom_radius = 0.14
	core_mesh.height = HEIGHT
	core_mesh.radial_segments = 8
	_core.mesh = core_mesh
	_core.position.y = HEIGHT * 0.5
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	core_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	core_mat.disable_receive_shadows = true
	core_mat.albedo_color = Color(1, 1, 1, 0.98)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1, 1, 0.92)
	core_mat.emission_energy_multiplier = 4.5
	_core.material_override = core_mat
	add_child(_core)
	# Cabang kecil kiri-kanan buat kesan bercabang.
	for i in 2:
		var branch := MeshInstance3D.new()
		branch.name = "Branch%d" % i
		var bmesh := CylinderMesh.new()
		bmesh.top_radius = 0.015
		bmesh.bottom_radius = 0.09
		bmesh.height = HEIGHT * 0.55
		bmesh.radial_segments = 6
		branch.mesh = bmesh
		branch.position.y = HEIGHT * 0.55
		branch.rotation.z = (0.18 if i == 0 else -0.22)
		branch.position.x = (0.18 if i == 0 else -0.16)
		var bmat := StandardMaterial3D.new()
		bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		bmat.albedo_color = Color(0.78, 0.88, 1.0, 0.45)
		bmat.emission_enabled = true
		bmat.emission = Color(0.6, 0.75, 1.0)
		bmat.emission_energy_multiplier = 2.2
		branch.material_override = bmat
		add_child(branch)


func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	_ring.name = "ImpactRing"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.2
	mesh.bottom_radius = 0.2
	mesh.height = 0.04
	mesh.radial_segments = 24
	_ring.mesh = mesh
	_ring.position.y = 0.04
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.disable_receive_shadows = true
	mat.albedo_color = Color(0.55, 0.7, 1.0, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.45, 0.65, 1.0)
	mat.emission_energy_multiplier = 2.8
	_ring.material_override = mat
	add_child(_ring)


func _build_flash() -> void:
	_flash = MeshInstance3D.new()
	_flash.name = "GroundFlash"
	var quad := QuadMesh.new()
	quad.size = Vector2(5.2, 5.2)
	_flash.mesh = quad
	_flash.position.y = 0.02
	_flash.rotation.x = -PI * 0.5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.disable_receive_shadows = true
	mat.albedo_color = Color(0.62, 0.78, 1.0, 0.55)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.8, 1.0)
	mat.emission_energy_multiplier = 2.0
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0, 0.35, 1])
	grad.colors = PackedColorArray([
		Color(1, 1, 1, 0.95), Color(0.7, 0.85, 1.0, 0.5), Color(0, 0, 0, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0)
	mat.albedo_texture = tex
	mat.emission_texture = tex
	_flash.material_override = mat
	add_child(_flash)


func _build_light() -> void:
	_light = OmniLight3D.new()
	_light.name = "BoltLight"
	_light.light_color = Color(0.68, 0.78, 1.0)
	_light.light_energy = 6.0
	_light.omni_range = 14.0
	_light.position.y = 1.2
	_light.shadow_enabled = false
	add_child(_light)


func _build_sparks() -> void:
	_sparks = GPUParticles3D.new()
	_sparks.name = "BoltSparks"
	_sparks.amount = 22
	_sparks.lifetime = 0.45
	_sparks.one_shot = true
	_sparks.emitting = true
	_sparks.local_coords = false
	_sparks.visibility_aabb = AABB(Vector3(-3, 0, -3), Vector3(6, 4, 6))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.12
	mat.direction = Vector3.UP
	mat.spread = 180.0
	mat.initial_velocity_min = 2.2
	mat.initial_velocity_max = 5.5
	mat.gravity = Vector3(0, -6, 0)
	mat.linear_accel_min = -1.0
	mat.linear_accel_max = 0.5
	mat.scale_min = 0.12
	mat.scale_max = 0.28
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	var tex := CurveTexture.new()
	tex.curve = curve
	mat.scale_curve = tex
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0, 0.5, 1])
	grad.colors = PackedColorArray([
		Color(1, 1, 1), Color(0.7, 0.85, 1.0), Color(0.35, 0.55, 1.0, 0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	mat.color_ramp = ramp
	_sparks.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.18, 0.18)
	var qmat := StandardMaterial3D.new()
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qmat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	qmat.disable_receive_shadows = true
	qmat.vertex_color_use_as_albedo = true
	qmat.albedo_color = Color.WHITE
	quad.material = qmat
	_sparks.draw_pass_1 = quad
	add_child(_sparks)


func _apply_damage() -> void:
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = radius_value
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3(0, 0.5, 0))
	query.collision_mask = 4
	query.collide_with_bodies = true
	query.collide_with_areas = true
	var hits := space.intersect_shape(query, 32)
	for hit in hits:
		var collider: Object = hit["collider"]
		if collider != null and collider.has_method("take_damage"):
			collider.call("take_damage", damage_value)
	# Fallback jarak: jika physics query kosong (zombie capsule aneh),
	# cari manual dari parent.
	if hits.is_empty():
		_damage_fallback()


func _damage_fallback() -> void:
	var root := get_parent()
	if root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.has_method("take_damage") and node is Node3D:
			var body := node as Node3D
			if body.global_position.distance_to(global_position) <= radius_value + 0.6:
				if not body.has_method("can_be_targeted") \
						or bool(body.call("can_be_targeted")):
					body.call("take_damage", damage_value)
		for child in node.get_children():
			stack.append(child)


func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / LIFETIME, 0, 1)
	# Beam menipis dan memudar.
	var beam_alpha := 1.0 - pow(t, 1.8)
	if _beam and _beam.material_override is StandardMaterial3D:
		var mat := _beam.material_override as StandardMaterial3D
		mat.albedo_color.a = beam_alpha * 0.92
	if _core and _core.material_override is StandardMaterial3D:
		var cmat := _core.material_override as StandardMaterial3D
		cmat.albedo_color.a = beam_alpha
	# Ring membesar.
	if _ring:
		var s := 0.2 + t * 12.0
		_ring.scale = Vector3(s, 1, s)
		if _ring.material_override is StandardMaterial3D:
			var rmat := _ring.material_override as StandardMaterial3D
			rmat.albedo_color.a = (1.0 - t) * 0.9
	if _flash:
		var fs := 1.0 + t * 0.5
		_flash.scale = Vector3(fs, fs, 1)
		if _flash.material_override is StandardMaterial3D:
			var fmat := _flash.material_override as StandardMaterial3D
			fmat.albedo_color.a = (1.0 - t) * 0.55
	# Kedip halus.
	var flicker := 1.0 + sin(_age * 48.0) * 0.08
	_beam.scale = Vector3(flicker, 1, flicker)
	_core.scale = Vector3(flicker, 1, flicker)
	if _age >= LIFETIME:
		queue_free()
