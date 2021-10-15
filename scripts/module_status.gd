extends Node2D

onready var body = get_parent()
onready var face = get_node("../Face")
onready var glue = get_node("../Glue")

onready var player_progression = get_node("/root/Main/Map/PlayerProgression")
onready var player_manager = get_node("/root/Main/PlayerManager")

var player_num : int = -1
var shape_name : String = ""

var time_penalty : float = 0.0
var has_finished : bool = false

# Deletes the whole body, but not before (re)setting all sorts of other properties
# that _should_ be properly reset
func delete():
	player_progression.on_body_removed(body)
	player_manager.deregister_body(body)
	
	body.get_node("Glue").disable_glue()
	
	body.remove_from_group("Players")
	get_node("../RoomTracker").get_cur_room().remove_player(body)
	
	body.queue_free()

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
	
	player_manager.register_body(body)

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

func make_wolf():
	glue.make_wolf()
	face.make_wolf()

func make_sheep():
	glue.make_sheep()
	face.make_sheep()
