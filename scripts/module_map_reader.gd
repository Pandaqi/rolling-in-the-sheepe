extends Node2D

onready var main_node = get_node("/root/Main")
onready var map = get_node("/root/Main/Map")
onready var body = get_parent()

onready var GUI = get_node("/root/Main/GUI")
var player_gui_scene = preload("res://scenes/player_gui.tscn")
var gui

var has_finished : bool = false

func _physics_process(dt):
	if has_finished: 
		position_gui_above_us()
		return
	
	var cur_cell = map.get_cell_from_node(self)
	var terrain = cur_cell.terrain
	var room = map.get_room_at(cur_cell.pos) # can be null??
	
	if terrain == "finish":
		finish()
	
	elif terrain == "teleporter":
		room.lock_module.register_player(body)

func finish():
	has_finished = true
	
	var finish_data = main_node.player_finished(body)
	if not finish_data.already_finished: 
		show_gui()
		set_gui_rank(finish_data.rank)
	
	disable_everything()

func has_gui():
	return gui != null

func show_gui():
	gui = player_gui_scene.instance()
	GUI.add_child(gui)

func set_gui_rank(r):
	gui.get_node("Label/Label").set_text("#" + str(r+1))

func position_gui_above_us():
	var pos = body.get_global_transform_with_canvas().origin
	var offset = Vector2.UP * 50
	
	gui.set_position(pos + offset)

func disable_everything():
	body.collision_layer = 2
	body.collision_mask = 2
	
	body.modulate.a = 0.5

