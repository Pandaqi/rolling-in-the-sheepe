extends Node2D

onready var my_item = get_parent()

var platform
var platform_scene = preload("res://scenes/projectiles/platform.tscn")
var tween_dur : float = 0.5

const MAX_PLATFORM_ANGLES : int = 16
const TIMER_BOUNDS = { 'min': 3, 'max': 8 }

onready var timer = $Timer
onready var tween = $Tween

func _ready():
	create_platform()
	_on_Timer_timeout()

func create_platform():
	platform = platform_scene.instance()
	add_child(platform)

func _on_Timer_timeout():
	hide_platform()
	restart_timer()

func restart_timer():
	timer.wait_time = rand_range(TIMER_BOUNDS.min, TIMER_BOUNDS.max)
	timer.start()

func show_platform():
	tween.interpolate_property(platform, "scale",
		Vector2.ZERO, Vector2.ONE, tween_dur,
		Tween.TRANS_BOUNCE, Tween.TRANS_LINEAR)
	tween.start()

func hide_platform():
	tween.interpolate_property(platform, "scale",
		Vector2.ONE, Vector2.ZERO, tween_dur,
		Tween.TRANS_BOUNCE, Tween.TRANS_LINEAR)
	tween.start()

func reposition_platform():
	var normal = my_item.global_transform.x
	var pos = my_item.global_position
	var possible_tiles = []
	
	# find a free position that's _somewhere_ near the column/row of our platform
	var bad_pos : bool = true
	var temp_pos
	var num_tries = 0
	while bad_pos:
		temp_pos = my_item.my_room.rect.get_free_real_pos_inside()
		bad_pos = (temp_pos - pos).dot(normal) < 0.85
		num_tries += 1
		if num_tries > 100: break

	# move it around a bit for randomness (and to allow cutting into half-open tiles)
	temp_pos += Vector2(randf()-0.5, randf()-0.5)*64.0
	platform.global_position = temp_pos

	var int_rot = randi() % MAX_PLATFORM_ANGLES
	var radian_rot = int_rot * (2*PI/float(MAX_PLATFORM_ANGLES))
	platform.global_rotation = radian_rot

func _on_Tween_tween_all_completed():
	if platform.scale.length() <= 0.03:
		reposition_platform()
		show_platform()
