extends Node

onready var players = get_node("../PlayerManager")

func _unhandled_input(ev):
	check_device_status(ev)

func check_device_status(ev):
	var res = GInput.check_new_player(ev)
	if not res.failed:
		players.create_menu_player(GInput.get_player_count() - 1)
	
	# TO DO: also add option for REMOVING player/LOGGING out
