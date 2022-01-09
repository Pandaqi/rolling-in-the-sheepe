extends Node2D

const MOVE_SPEED : float = 60.0
const MIN_DISTANCE_TO_TRAVEL : float = 64.0*2.0

onready var my_item = get_parent()

var platform
var platform_scene = preload("res://scenes/projectiles/platform.tscn")
var move_dir : int = 1
var normal : Vector2
var distance_traveled_in_cur_dir : float = 0.0

func _ready():
	create_platform()
	update_normal()

func create_platform():
	platform = platform_scene.instance()
	add_child(platform)
	platform.set_position(Vector2.RIGHT*32)

func _physics_process(dt):
	var offset = move_dir * normal * MOVE_SPEED * dt
	platform.global_position += offset
	distance_traveled_in_cur_dir += offset.length()
	
	check_for_flip()

func check_for_flip():
	if distance_traveled_in_cur_dir < MIN_DISTANCE_TO_TRAVEL: return
	
	var space_state = get_world_2d().direct_space_state
	var start = platform.global_position
	var end = start + move_dir*normal*20.0

	var collision_layer = 2
	var result = space_state.intersect_ray(start, end, [platform], collision_layer)
	if not result: return
	
	move_dir *= -1
	distance_traveled_in_cur_dir = 0.0
	update_normal()

func update_normal():
	normal = my_item.global_transform.x
	platform.global_rotation = normal.angle()
