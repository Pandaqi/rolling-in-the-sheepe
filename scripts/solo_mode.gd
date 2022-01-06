extends Node2D

var active : bool = false
var temp_disabled : bool = false
var last_known_room = null

const FILL_INTERVAL : float = 0.5

onready var timer = $Timer
onready var disable_timer = $DisableTimer
onready var main_node = get_parent()

func activate():
	active = GInput.get_player_count()
	if not active: return
	
	print("STARTING SOLO MODO")
	
	restart_timer()
	disable_temporarily()

func deactivate():
	active = false
	timer.stop()

func is_active():
	return active

func move_further_along():
	if temp_disabled: return
	
	var room = main_node.map.route_generator.get_oldest_room()
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
	
	if sort_arr.size() <= 0:
		game_over()
		return
	
	sort_arr.sort_custom(self, "custom_sort")
	
	# the first cell is the one with shortest distance into room, so the one "furthest back"
	# so take that, and fill it, and inform surroundings
	var final_cell = sort_arr[0].pos
	main_node.map.change_cell(final_cell, 0)
	main_node.map.update_bitmask(final_cell, Vector2.ONE)
	
	print("FILLING CELL")
	print(final_cell)
	
	# destroy any players/bodies here
	main_node.map.destroy_nodes_at_cell(final_cell)
	
	# we're dead?
	# or somehow this didn't work, and the player is stuck somewhere BEHIND the algorithm? destroy us as well
	var num_players_left = get_tree().get_nodes_in_group("Players").size()
	var stuck_behind = last_known_room and last_known_room.route.index < room.route.index

	if num_players_left <= 0 or stuck_behind:
		game_over()
		return

	# filled everything? destroy the room
	if sort_arr.size() <= 1:
		main_node.map.route_generator.delete_oldest_room()
	
	var leading_player = main_node.map.player_progression.get_leading_player()
	if not leading_player: return
	
	var new_room = leading_player.room_tracker.get_cur_room()
	if not new_room: return
	
	last_known_room = new_room

func game_over():
	deactivate()
	main_node.state.game_over(false)

func custom_sort(a,b):
	return a.score < b.score

func _on_Timer_timeout():
	if not active: return
	move_further_along()
	restart_timer()

func restart_timer():
	timer.wait_time = determine_timer_interval()
	timer.start()

func determine_timer_interval() -> float:
	var leading_player = main_node.map.player_progression.get_leading_player()
	if not leading_player: return FILL_INTERVAL
	
	var frontmost_index = leading_player.room_tracker.get_cur_room().route.index
	var avg_dist = 4
	var scalar = 0.5 + 0.5 * (avg_dist / (frontmost_index + 1))
	
	var final_interval = scalar * FILL_INTERVAL
	return final_interval

func disable_temporarily():
	temp_disabled = true
	disable_timer.start()

func _on_DisableTimer_timeout():
	temp_disabled = false
