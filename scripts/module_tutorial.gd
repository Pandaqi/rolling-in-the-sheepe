extends Node2D

onready var body = get_parent()

onready var map = get_node("/root/Main/Map")
onready var sprite = $Sprite

const MAX_TIME_BETWEEN_STEPS : int = 15
onready var timer = $Timer

var tutorial_step : int = -1
var base_frames = [0,8,97]

const MOVEMENT_BEFORE_NEXT_STEP : float = 3.0 # in _seconds_, regardless of speed
var player_movement : float = 0.0

var active : bool = false

func _module_ready():
	activate()

func activate():
	active = true
	
	if GInput.is_keyboard_player(body.status.player_num):
		base_frames.erase(97)
	
	remove_child(sprite)
	body.GUI.add_child(sprite)
	
	load_next_step()

func load_next_step():
	tutorial_step += 1
	
	if tutorial_step >= base_frames.size():
		player_movement = 0.0
		sprite.queue_free()
		queue_free()
		return
	
	var device_id = GInput.get_device_id(body.status.player_num)
	var base_frame = base_frames[tutorial_step]
	if device_id < 0:
		base_frame += abs(device_id + 1)
	else:
		base_frame += 4
	
	# EXCEPTION: controller tutorial gets an extra step, but keyboard doesn't, so we just take the raw value
	# (if we need more exceptions, we need cleaner code for that, but eh ...)
	if base_frames[tutorial_step] == 97:
		base_frame = 97
	
	sprite.set_frame(base_frame)
	player_movement = 0.0
	
	timer.stop()
	timer.wait_time = MAX_TIME_BETWEEN_STEPS
	timer.start()

func _physics_process(dt):
	if not active: return
	check_player_movement(dt)
	position_sprite_above_player()

func check_player_movement(dt):
	var epsilon = 1.0
	
	if tutorial_step == 0 and body.angular_velocity > epsilon:
		player_movement += dt
	elif tutorial_step == 1 and body.angular_velocity < -epsilon:
		player_movement += dt
	
	if player_movement > MOVEMENT_BEFORE_NEXT_STEP:
		load_next_step()

func position_sprite_above_player():
	var pos = body.get_global_transform_with_canvas().origin
	var offset = Vector2.UP * 75
	sprite.set_position(pos + offset)

func _on_Timer_timeout():
	load_next_step()
