extends Node

var players_inside = []

onready var lock = get_node("../Lock")

func add_player(p):
	players_inside.append(p)
	lock.on_body_enter(p)

func remove_player(p):
	players_inside.erase(p)
	lock.on_body_exit(p)

func get_them():
	return players_inside

func count():
	return players_inside.size()
