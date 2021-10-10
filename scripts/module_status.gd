extends Node2D

var player_num : int = -1

func set_player_num(num):
	player_num = num
	
	if has_node("../Input"):
		get_node("../Input").set_player_num(num)
