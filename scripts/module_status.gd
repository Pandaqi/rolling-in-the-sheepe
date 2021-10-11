extends Node2D

var player_manager
var player_num : int = -1

func set_player_num(manager, num : int):
	player_manager = manager
	player_num = num
	
	if has_node("../Input"):
		get_node("../Input").set_player_num(num)
	
	if has_node("../Shaper"):
		get_node("../Shaper").set_color(player_manager.player_colors[num])
