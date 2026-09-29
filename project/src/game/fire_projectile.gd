extends CharacterBody3D

signal impacted(point: Vector3, normal: Vector3)

const Visual = preload("res://src/game/fire_visual.gd")
const GRAVITY := Vector3(0, -12, 0)
const MAX_LIFETIME := 4.0

var age := 0.0
var finished := false
var _trail: Array[MeshInstance3D] = []
var _history: Array[Vector3] = []


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.11
	collision.shape = sphere
	add_child(collision)
	add_child(Visual.make_orb(0.17))
	for index in range(4):
		var spark := Visual.make_orb(0.10 - index * 0.018)
		add_child(spark)
		_trail.append(spark)
		_history.append(global_position)


func _physics_process(delta: float) -> void:
	if finished:
		return
	age += delta
	if age >= MAX_LIFETIME:
		finished = true
		queue_free()
		return
	# Sweep sphere, bukan sekadar cek posisi akhir: menghindari menembus collider tipis.
	var motion := velocity * delta + GRAVITY * (0.5 * delta * delta)
	velocity += GRAVITY * delta
	var collision := move_and_collide(motion, false, 0.005)
	if collision != null:
		finished = true
		impacted.emit(collision.get_position(), collision.get_normal())
		queue_free()
		return
	_history.push_front(global_position)
	if _history.size() > 12:
		_history.pop_back()
	for index in range(_trail.size()):
		_trail[index].global_position = _history[mini((index + 1) * 2, _history.size() - 1)]
