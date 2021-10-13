extends Node2D

var leading_player
var trailing_player

func _physics_process(_dt):
	determine_leading_and_trailing_player()
	
func determine_leading_and_trailing_player():
	var max_room = -INF
	var min_room = INF
	
	leading_player = null
	trailing_player = null
	
	var players = get_tree().get_nodes_in_group("Players")
	for p in players:
		if not is_instance_valid(p): continue
		
		var index = p.get_node("RoomTracker").get_cur_room().index
		
		if index > max_room:
			max_room = index
			leading_player = p
		
		if index < min_room:
			min_room = index
			trailing_player = p

func has_leading_player():
	return leading_player and is_instance_valid(leading_player)

func has_trailing_player():
	return trailing_player and is_instance_valid(trailing_player)

func get_leading_player():
	return leading_player

func get_trailing_player():
	return trailing_player

func on_body_sliced(b):
	if b == leading_player:
		leading_player = null
	
	elif b == trailing_player:
		trailing_player = null
