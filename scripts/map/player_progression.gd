extends Node2D

var leading_player
var trailing_player

func _physics_process(_dt):
	determine_leading_and_trailing_player()
	
func determine_leading_and_trailing_player():
	var max_room = -INF
	var max_dist_in_room = -INF
	var min_room = INF
	var min_dist_in_room = INF
	
	var players = get_tree().get_nodes_in_group("Players")
	var new_leading_player = null
	var new_trailing_player = null
	for p in players:
		if not is_instance_valid(p): continue
		
		var index = p.get_node("RoomTracker").get_cur_room().index
		var dist_in_room = p.get_node("RoomTracker").get_dist_in_room()
		
		if index > max_room:
			max_room = index
			max_dist_in_room = dist_in_room
			new_leading_player = p
		
		elif index == max_room:
			if dist_in_room > max_dist_in_room:
				max_dist_in_room = dist_in_room
				new_leading_player = p
		
		if index < min_room:
			min_room = index
			min_dist_in_room = dist_in_room
			new_trailing_player = p
		
		elif index == min_room:
			if dist_in_room < min_dist_in_room:
				min_dist_in_room = dist_in_room
				new_trailing_player = p
	
	set_leading_player(new_leading_player)
	set_trailing_player(new_trailing_player)

func set_leading_player(p):
	if p == leading_player: return
	
	leading_player = p

func set_trailing_player(p):
	if p == trailing_player: return

	# change old trailing player back to sheep
	if has_trailing_player():
		trailing_player.get_node("Status").make_sheep()
	
	# change new one to a wolf
	trailing_player = p
	trailing_player.get_node("Status").make_wolf()
	
func has_leading_player():
	return leading_player and is_instance_valid(leading_player)

func has_trailing_player():
	return trailing_player and is_instance_valid(trailing_player)

func get_leading_player():
	return leading_player

func get_trailing_player():
	return trailing_player

func on_body_removed(b):
	if b == leading_player:
		leading_player = null
	
	elif b == trailing_player:
		trailing_player = null
