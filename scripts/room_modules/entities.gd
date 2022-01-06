extends Node

var players_inside = []

onready var parent = get_parent()

func add_player(p):
	players_inside.append(p)
	parent.lock.on_body_enter(p)

func remove_player(p):
	players_inside.erase(p)
	parent.lock.on_body_exit(p)

func get_them():
	return players_inside

func count():
	return players_inside.size()

func delete():
	for p in players_inside:
		p.status.delete(false)
