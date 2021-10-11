extends Node2D

onready var player_manager = get_node("/root/Main/PlayerManager")
var player_num : int = -1

func set_player_num(num : int):
	player_num = num
	
	if has_node("../Input"):
		get_node("../Input").set_player_num(num)
	
	if has_node("../Shaper"):
		get_node("../Shaper").set_color(player_manager.player_colors[num])
