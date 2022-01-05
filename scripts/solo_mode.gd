extends Node2D

var active : bool = false

const FILL_INTERVAL : float = 0.5

onready var timer = $Timer
onready var map = get_node("../Map")
onready var player_manager = get_node("../PlayerManager")

func activate():
	active = GInput.get_player_count()
	if not active: return
	
	print("STARTING SOLO MODO")
	
	restart_timer()

func is_active():
	return active

func move_further_along():
	var room = map.route_generator.get_oldest_room()
	if not room: return
	
	# TO DO: Can be optimized by just saving the empty positions whenever we enter a NEW room
	# And modifying/remembering that array until it's empty
	var pos_arr = room.tilemap.get_empty_positions()
	pos_arr.shuffle()
	
	var dir = room.route.dir
	var sort_arr = []
	var top_left = room.rect.get_shrunk().pos
	for pos in pos_arr:
		var score
		if dir == 0:
			score = pos.x - top_left.x
		elif dir == 2:
			score = top_left.x - pos.x
		elif dir == 1:
			score = pos.y - top_left.y
		elif dir == 3:
			score = top_left.y - pos.y
		
		sort_arr.append({
			'pos': pos,
			'score': score
		})
	
	sort_arr.sort_custom(self, "custom_sort")
	
	# the first cell is the one with shortest distance into room, so the one "furthest back"
	# so take that, and fill it, and inform surroundings
	var final_cell = sort_arr[0].pos
	map.change_cell(final_cell, 0)
	map.update_bitmask(final_cell, Vector2.ONE)
	
	print("FILLING CELL")
	print(final_cell)
	
	# destroy any players/bodies here
	map.destroy_nodes_at_cell(final_cell)
	
	var num_players_left = get_tree().get_nodes_in_group("Players").size()
	if num_players_left <= 0:
		print("GAME OVER AND YOU LOST")
	
	# filled everything? destroy the room
	if sort_arr.size() <= 1:
		map.route_generator.delete_oldest_room()

func custom_sort(a,b):
	return a.score < b.score

func _on_Timer_timeout():
	move_further_along()
	restart_timer()

func restart_timer():
	timer.wait_time = determine_timer_interval()
	timer.start()

func determine_timer_interval() -> float:
	var leading_player = map.player_progression.get_leading_player()
	if not leading_player: return FILL_INTERVAL
	
	var frontmost_index = leading_player.room_tracker.get_cur_room().route.index
	var avg_dist = 4
	var scalar = 0.5 + 0.5 * (avg_dist / (frontmost_index + 1))
	
	var final_interval = scalar * FILL_INTERVAL
	return final_interval
