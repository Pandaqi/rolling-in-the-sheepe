extends Node2D

onready var body = get_parent()
onready var player_manager = get_node("/root/Main/PlayerManager")

var player_num : int = -1
var shape_name : String = ""

var time_penalty : float = 0.0

func set_shape_name(nm : String):
	shape_name = nm

func set_player_num(num : int):
	player_num = num
	
	if has_node("../Input"):
		get_node("../Input").set_player_num(num)
	
	if has_node("../Glue"):
		get_node("../Glue").set_player_num(num)
	
	if has_node("../Shaper"):
		get_node("../Shaper").set_color(player_manager.player_colors[num])
	
	if has_node("../Tutorial"):
		var global_tutorial = get_node("/root/Main/Tutorial")
		var module_tutorial = get_node("../Tutorial")
		if global_tutorial.is_active():
			module_tutorial.activate()
		else:
			module_tutorial.queue_free()

func modify_time_penalty(val):
	time_penalty += val

func make_ghost():
	body.collision_layer = 0
	body.collision_mask = 1
	
	body.modulate.a = 0.5

# Layers 1 (2^0; all) and 3 (2^2; players)
func undo_ghost():
	body.collision_layer = 1 + 4
	body.collision_mask = 1 + 4
	
	body.modulate.a = 1.0
