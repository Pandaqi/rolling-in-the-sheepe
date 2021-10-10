extends Node2D

var player_scene = preload("res://scenes/body.tscn")

onready var map = get_node("/root/Main/Map")

func activate():
	if GlobalInput.get_player_count() <= 0:
		GlobalInput.create_debugging_players()
	
	create_players()

func create_players():
	for i in range(GlobalInput.get_player_count()):
		create_player(i)

func create_player(player_num : int):
	var player = player_scene.instance()
	
	player.get_node("Shaper").create_from_random_shape()
	player.get_node("Status").set_player_num(player_num)
	
	player.set_position(map.place_inside_room(map.cur_path[0]))
	map.call_deferred("add_child", player)
	
