extends Node

const DELAY_BETWEEN_SWITCH : float = 1.0 # in seconds

var leading_player = null
var trailing_player = null

var wanted_leading_player = null
var wanted_trailing_player = null

var time_since_leader_switch : float = -1
var time_since_trail_switch : float = -1

var wolf_disabled : bool = false

onready var route_generator = get_node("../RouteGenerator")

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
		
		var index = p.get_node("RoomTracker").get_cur_room().route.index
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
	
	var cur_time = OS.get_ticks_msec()
	if new_leading_player != wanted_leading_player:
		time_since_leader_switch = OS.get_ticks_msec()
		wanted_leading_player = new_leading_player
		
		# NOTE: this makes the switch instant, if currently nothing is set
		if leading_player == null:
			time_since_leader_switch = -INF
	
	if (cur_time - time_since_leader_switch)/1000.0 > DELAY_BETWEEN_SWITCH:
		set_leading_player(wanted_leading_player)
	
	if new_trailing_player != wanted_trailing_player:
		time_since_trail_switch = OS.get_ticks_msec()
		wanted_trailing_player = new_trailing_player
		
		if trailing_player == null:
			time_since_trail_switch = -INF
	
	if (cur_time - time_since_trail_switch)/1000.0 > DELAY_BETWEEN_SWITCH:
		set_trailing_player(wanted_trailing_player)
	
	# change new one to a wolf
	check_wolf()

#
# Helpers/Queries
#
func get_distance_to_generation_end():
	if not has_leading_player(): return
	
	var index = leading_player.get_node("RoomTracker").get_cur_room().route.index
	return (route_generator.cur_path.size() - index)

#
# Wolf handling
#
func check_wolf():
	if not has_trailing_player(): return
	
	var wolf_creation_is_allowed = (trailing_player.get_node("RoomTracker").get_cur_room().route.index > 1) and (not wolf_disabled)
	if not wolf_creation_is_allowed: return
	
	var already_is_wolf = trailing_player.get_node("Status").is_wolf
	if already_is_wolf: return
	
	trailing_player.get_node("Status").make_wolf()

func enable_wolf():
	wolf_disabled = false
	check_wolf()

func disable_wolf():
	wolf_disabled = true
	if not has_trailing_player(): return
	
	trailing_player.get_node("Status").make_sheep()

#
# Helper functions (for ourself but also all other nodes accesssing us)
# for leading/trailing players
#
func set_leading_player(p):
	if p == leading_player: return
	
	leading_player = p

func set_trailing_player(p):
	if p == trailing_player: return

	# change old trailing player back to sheep
	if has_trailing_player():
		trailing_player.get_node("Status").make_sheep()
	
	trailing_player = p
	
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