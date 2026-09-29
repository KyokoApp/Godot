extends Node3D
## MAIN SCENE — titik masuk game.
##
## MILESTONE 1 (2026-09-29): dunia paling sederhana yang masih berarti.
## Tujuannya BUKAN cantik — tujuannya membuktikan satu hal: aplikasi ini
## benar-benar bisa dibuka di HP dan menampilkan sesuatu.
##
## Semua di sini dibangun dari kode, tanpa file .tscn yang rumit, supaya
## satu-satu bagian bisa ditambahkan dan diuji terpisah. Tidak ada shader
## kustom di milestone ini: kalau ada yang salah, penyebabnya jelas —
## bukan "entah shader mana".
##
## LANGKAH BERIKUTNYA (satu per satu, masing-masing diuji di HP):
##   2. Bergerak        — WASD/joystick + kamera mengikut
##   3. Delta update   — launcher mengunduh content pack
##   4. Dunia           — tanah, rumput, jalan
##   5. Karakter        — model + animasi

const Joystick = preload("res://src/game/virtual_joystick.gd")
const MOVE_SPEED := 5.0
const CAMERA_OFFSET := Vector3(0.0, 3.2, 7.0)

const GROUND_SIZE := 120.0
const CHARACTER_HEIGHT := 1.8

var _label: Label
var _camera: Camera3D
var _player: CharacterBody3D
var _visual: Node3D
var _joystick: Joystick


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_player()
	_build_camera()
	_build_hud()
	print("[main] milestone 2A siap")


# ---------------------------------------------------------------- dunia ----

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.52, 0.86)
	sky_mat.sky_horizon_color = Color(0.78, 0.85, 0.92)
	sky_mat.ground_bottom_color = Color(0.28, 0.34, 0.26)
	sky_mat.ground_horizon_color = Color(0.62, 0.68, 0.58)
	sky.sky_material = sky_mat
	env.sky = sky
	# Cerah agar bentuk-bentuk terbaca jelas di layar HP apa pun.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 135.0, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)


func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.36, 0.56, 0.27)
	mat.roughness = 1.0

	var mesh := MeshInstance3D.new()
	mesh.name = "Ground"
	mesh.mesh = plane
	mesh.material_override = mat
	add_child(mesh)

	# Collider infinite: selalu menyangga pemain, tak ada tepi yang bisa
	# membuat pemain jatuh melewati batas.
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	add_child(body)


# ------------------------------------------------------------- karakter ----

func _build_player() -> void:
	var body := CharacterBody3D.new()
	body.name = "Player"
	body.position.y = CHARACTER_HEIGHT / 2.0 + 0.02
	body.collision_layer = 2
	body.collision_mask = 1

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = CHARACTER_HEIGHT
	shape.shape = capsule
	body.add_child(shape)

	var visual := Node3D.new()
	visual.name = "Visual"
	_visual = visual
	body.add_child(visual)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.40, 0.75)

	var cap := CapsuleMesh.new()
	cap.radius = 0.3
	cap.height = CHARACTER_HEIGHT
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = cap
	mi.material_override = mat
	visual.add_child(mi)

	# Pembeda arah hadap supaya jelas menghadap ke mana. Satu kerucut kecil
	# di depan — jauh lebih murah daripada model penuh, dan cukup untuk
	# memastikan kontrol kamera nanti tidak terbalik.
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.95, 0.85, 0.35)
	var nose := MeshInstance3D.new()
	var nose_mesh := CylinderMesh.new()
	nose_mesh.top_radius = 0.0
	nose_mesh.bottom_radius = 0.14
	nose_mesh.height = 0.3
	nose_mesh.radial_segments = 8
	nose.mesh = nose_mesh
	nose.material_override = nose_mat
	nose.position = Vector3(0.0, 0.35, -0.42)
	visual.add_child(nose)

	add_child(body)
	_player = body


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.name = "Camera"
	_camera.position = Vector3(0.0, 3.0, 6.0)
	_camera.current = true
	_camera.fov = 70.0
	add_child(_camera)


# ------------------------------------------------------------------ HUD ----

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_label = Label.new()
	_label.text = "MILESTONE 2A — joystick gerak"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_label.add_theme_color_override("font_shadow", Color(0, 0, 0, 0.8))
	_label.position = Vector2(24, 24)
	layer.add_child(_label)

	_joystick = Joystick.new()
	layer.add_child(_joystick)
	_joystick.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# ----------------------------------------------------------------- loop ----

func _physics_process(delta: float) -> void:
	var stick := _joystick.direction
	# Arah layar tetap: atas joystick = menjauh dari kamera (sumbu -Z).
	var movement := Vector3(stick.x, 0.0, stick.y)
	_player.velocity.x = movement.x * MOVE_SPEED
	_player.velocity.z = movement.z * MOVE_SPEED
	if not _player.is_on_floor():
		_player.velocity += _player.get_gravity() * delta
	else:
		_player.velocity.y = 0.0
	_player.move_and_slide()
	# Area uji masih berupa plane; jangan biarkan pemain keluar tanah terlihat.
	var edge := GROUND_SIZE / 2.0 - 1.0
	_player.position.x = clampf(_player.position.x, -edge, edge)
	_player.position.z = clampf(_player.position.z, -edge, edge)
	if movement.length_squared() > 0.001:
		_visual.rotation.y = atan2(-movement.x, -movement.z)


func _process(_delta: float) -> void:
	_camera.position = _player.global_position + CAMERA_OFFSET
	_camera.look_at(_player.global_position + Vector3(0, 0.5, 0), Vector3.UP)
	_label.text = (
		"MILESTONE 2A — joystick gerak\nFPS: %d | Posisi: %.1f, %.1f\n"
		+ "Geser lingkaran kiri bawah. Lepaskan untuk berhenti."
	) % [Engine.get_frames_per_second(), _player.position.x, _player.position.z]
