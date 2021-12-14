extends Node

onready var main_node = get_parent()
onready var players = get_node("../PlayerManager")

func _unhandled_input(ev):
	check_device_status(ev)

func check_device_status(ev):
	var res = GlobalInput.check_new_player(ev)
	if not res.failed:
		players.create_menu_player(GlobalInput.get_player_count() - 1)
		main_node.on_player_logged_in()
	
	# TO DO: also add option for REMOVING player/LOGGING out
