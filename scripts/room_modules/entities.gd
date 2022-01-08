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
	# TO DO: this is a safeguard against crashes; but I should really find the original cause for the bug that _sometimes_ it has a wrong value
	for i in range(players_inside.size()-1,-1,-1):
		var p = players_inside[i]
		if not p or not is_instance_valid(p):
			players_inside.remove(i)
	
	return players_inside

func count():
	return players_inside.size()

func has_some():
	return count() > 0

func delete():
	if not parent.map.route_generator.is_teleporting:
		for p in players_inside:
			p.status.delete(false)
		
		players_inside = []
	
	for p in players_inside:
		p.room_tracker.on_room_removed()
