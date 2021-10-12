extends Node2D

onready var map = get_node("/root/Main/Map")
onready var GUI = get_node("/root/Main/GUI")
onready var sprite = $Sprite
onready var body = get_parent()

var tutorial_step : int = -1
var base_frames = [0,5]

var listen_for_changes : bool = true

func activate():
	remove_child(sprite)
	GUI.add_child(sprite)
	
	load_next_step()

func load_next_step():
	tutorial_step += 1
	
	if tutorial_step >= base_frames.size():
		sprite.queue_free()
		queue_free()
		return
	
	var device_id = GlobalInput.get_device_id(body.get_node("Status").player_num)
	var base_frame = base_frames[tutorial_step]
	if device_id < 0:
		base_frame += abs(device_id + 1)
	else:
		base_frame += 4
	
	sprite.set_frame(base_frame)
	
	pause_listening_for_changes()

func _physics_process(dt):
	check_for_progression()
	position_sprite_above_player()

func check_for_progression():
	if not listen_for_changes: return
	
	var cur_room = map.get_cell_from_node(body).room
	if tutorial_step == 0 and cur_room.dir == 2:
		load_next_step()
	elif tutorial_step == 1 and cur_room.dir != 2:
		load_next_step()

func position_sprite_above_player():
	var pos = body.get_global_transform_with_canvas().origin
	var offset = Vector2.UP * 50
	
	sprite.set_position(pos + offset)

func pause_listening_for_changes():
	$Timer.start()
	listen_for_changes = false

func _on_Timer_timeout():
	listen_for_changes = true
