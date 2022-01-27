extends Node

 # how many back rooms should stay on screen until they are DELETED
const NUM_ROOMS_BACK_BUFFER : int = 4

# how many rooms should be CREATED (AT MOST) in front of the leading player
const NUM_ROOMS_FRONT_BUFFER : int = 15

# with how many pre-created rooms we start each game
# Real value should be 10-15
const NUM_STARTING_ROOMS : int = 10

# the actual path of rooms, in order
var cur_path = []
var total_path_length : int = 0

# keep track of total room count, so we know when to finish
var total_rooms_created : int = 0
var rooms_until_finish : int = 0
var level_size_bounds : Vector2 = Vector2(200, 300) #Vector2(50, 60)
var has_finished : bool = false

# another tracker for when to place locks
var rooms_in_current_section : int = 0
var rooms_until_section_end : int = 0
var section_size_bounds : Vector2 = Vector2(40, 70) #Vector2(10, 20) 
var num_locks_placed : int = 0

# room generation is only paused when a teleporter has been placed
# (and we CAN'T continue, even if we wanted to
var pause_room_generation : bool = false

# used to make sure players stay alive while we're deleting + reconstructing the whole world
var is_teleporting : bool = false

onready var map = get_parent()
onready var room_picker = get_node("../RoomPicker")
onready var player_progression = get_node("../PlayerProgression")
onready var edges = get_node("../Edges")
onready var mask_painter = get_node("../MaskPainter")
onready var dynamic_tutorial = get_node("../DynamicTutorial")
onready var solo_mode = get_node("/root/Main/SoloMode")

var create_phase : bool = false

onready var disable_timer : Timer = $DisableTimer
var temporary_disable : bool = false

#
# Initialization
#
func initialize_rooms():
	for _i in range(NUM_STARTING_ROOMS):
		room_picker.create_new_room()
	
	$Timer.wait_time = (1.0 / GDict.cfg.generation_speed)
	$Timer.start()

func set_global_parameters():
	rooms_until_finish = int( floor(rand_range(level_size_bounds.x, level_size_bounds.y)))
	
	# to ensure the game ends immediately once the last tutorial has been shown
	rooms_until_finish = 0
	
	rooms_until_section_end = int( floor(rand_range(section_size_bounds.x, section_size_bounds.y)))

func generation_disallowed():
	return pause_room_generation or has_finished

func append_to_path(room):
	cur_path.append(room)
	total_path_length += 1

func get_total_path_length():
	return total_path_length

#
# Every frame update; core of algorithm (delete old rooms, add new)
#
func _on_Timer_timeout():
	if create_phase:
		check_for_new_room()
		create_phase = false
	
	else:
		check_for_old_room_deletion()
		create_phase = true

func check_for_new_room():
	if not player_progression.has_leading_player(): return
	if pause_room_generation: return
	if has_finished: return
	if temporary_disable: return
	
	var lead = player_progression.get_leading_player()
	var index = lead.room_tracker.get_cur_room().route.index
	var num_rooms_threshold = NUM_ROOMS_FRONT_BUFFER
	var far_enough_forward = (index > cur_path.size() - num_rooms_threshold)
	
	var very_far_forward = abs(cur_path.size() - 1 - index) < 6
	var num_rooms = 1
	if very_far_forward: num_rooms = 3
	
	if far_enough_forward:
		for _i in range(num_rooms):
			room_picker.create_new_room()

func check_for_old_room_deletion():
	if not player_progression.has_trailing_player(): return
	if solo_mode.is_active(): return
	if temporary_disable: return
	
	var trail = player_progression.get_trailing_player()
	var index = trail.room_tracker.get_cur_room().route.index
	var last_index_incl_backtrack = index
	
	# find the oldest point at which the route split
	# however, locks are a uniform "reset point" (you can't backtrack past it)
	# so if we encounter one, just stop searching right there
	for i in range(index, -1, -1):
		if cur_path[i].lock.has_lock_or_was_lock(): break
		if cur_path[i].is_backtrack:
			last_index_incl_backtrack = i
	
	var num_rooms_threshold = NUM_ROOMS_BACK_BUFFER
	var far_enough_from_last_room = (last_index_incl_backtrack > num_rooms_threshold)
	
	if far_enough_from_last_room:
		delete_oldest_room()

func delete_oldest_room():
	cur_path.pop_front().delete()

	# update the index of all surviving rooms
	# (should be lowered by exactly one, for all)
	for i in range(cur_path.size()):
		cur_path[i].route.set_index(i)

#
# Extra helpers for related situations (such as "clear map => delete all rooms")
#
func delete_all_rooms():
	# delete all the rooms
	while cur_path.size() > 0:
		delete_oldest_room()
	
	edges.remove_all()
	
	# clear the painting mask
	mask_painter.clear_mask()

func placed_finish():
	has_finished = true

func placed_lock():
	num_locks_placed += 1
	
	rooms_in_current_section = 0
	rooms_until_section_end = int( floor(rand_range(section_size_bounds.x, section_size_bounds.y)))

#
# Queries into the route
#
func should_place_finish():
	if GDict.cfg.debug_quick_finish:
		if total_rooms_created > 10: return true
	
	if GDict.cfg.delay_finish_until_all_taught:
		if not dynamic_tutorial.is_everything_taught(): 
			return false
		
		if num_locks_placed < GDict.cfg.min_locks_before_finish:
			return false
		
		if dynamic_tutorial.rooms_placed_since_last_tutorial < GDict.cfg.min_rooms_between_last_tut_and_finish:
			return false
	
	if GDict.cfg.debug_quick_dynamic_tutorial:
		return true
	
	return (total_rooms_created > rooms_until_finish)

func should_place_lock():
	 return (rooms_in_current_section > rooms_until_section_end) and cur_path.size() > 4

func get_new_room_index():
	return cur_path.size()

func room_rect_overlaps_path(rect, params):
	for x in range(rect.size.x):
		for y in range(rect.size.y):
			var my_pos = rect.pos + Vector2(x,y)
			if map.out_of_bounds(my_pos): return true
			
			var cur_room = map.get_room_at(my_pos)
			
			if not cur_room: continue
			
			# What do we do here?
			# We're allowed to overlap our previous room, as that's what we connect with, so that's a guarantee
			# HOWEVER, if they have an "old_room", it means we're overlapping _multiple rooms at once_, which surely isn't allowed.
			if cur_room.route.index == params.prev_room.route.index and not map.get_cell(my_pos).old_room: continue
			
			return true
	return false

func get_cur_room(p : RigidBody2D):
	var pos = p.get_global_position()
	var grid_pos = (pos / map.TILE_SIZE).floor()
	return map.get_room_at(grid_pos)

func get_furthest_room():
	if cur_path.size() == 0: return null
	return cur_path[cur_path.size()-1]

func get_oldest_room():
	if cur_path.size() <= 0: return null
	return cur_path[0]

func get_path_from_front(offset : int = 0):
	var index = cur_path.size() - 1 - offset
	if index < 0: return null
	
	return cur_path[index]

func get_offset_from(start, offset : int):
	var target = clamp(start + offset, 0, cur_path.size()-1)
	return cur_path[target]

func get_average_room_size_over_last(offset : int):
	var start = max(cur_path.size() - offset, 0)
	var end = cur_path.size()
	
	offset = (end-start)
	if offset <= 0: return 0.0
	
	var sum : float = 0.0
	for i in range(start, end):
		var room = cur_path[i]
		sum += room.rect.get_area()
	
	return sum / offset

func get_pos_just_ahead():
	if not player_progression.has_leading_player(): return null
	
	var lead = player_progression.get_leading_player()
	var leading_room = lead.room_tracker.get_cur_room()
	if not leading_room: return null
	
	var index = lead.room_tracker.get_cur_room().route.index
	if index == (cur_path.size()-1): return null
	
	var coming_positions : Vector2 = Vector2.ZERO
	var num_positions_considered : float = 0
	
	var max_rooms_to_look_ahead = 2
	var max_bound = min(cur_path.size(), index+max_rooms_to_look_ahead)
	
	for i in range(index+1, max_bound):
		var ratio : float = 1.0 / float(i-index)
		coming_positions += ratio * cur_path[i].rect.get_real_center()
		num_positions_considered += ratio
	
	coming_positions /= num_positions_considered
	
	var max_look_ahead_euclidian = 318
	var vec = (coming_positions - lead.get_global_position())
	var norm_vec = vec.normalized()
	var dist = min(vec.length(), max_look_ahead_euclidian)
	
	return lead.get_global_position() + norm_vec*dist

func get_next_best_player(p):
	var my_index = p.room_tracker.get_cur_room().route.index
	var my_num = p.status.player_num
	for i in range(my_index+1, cur_path.size()):
		var room = cur_path[i]
		
		for other_p in room.entities.get_them():
			var num = other_p.status.player_num
			if num == my_num: continue
			
			return other_p
	
	return player_progression.get_leading_player()

func get_ideal_teleporter_room():
	var max_backtracks = min(6, cur_path.size()-1)
	var biggest_room = null
	var biggest_size : int = -INF
	
	for i in range(max_backtracks):
		var room = get_path_from_front(i)
		if room.rect.get_area() <= biggest_size: continue
		if room.lock.has_lock(): continue
		if room.has_tutorial: continue
		if room.entities.has_some(): continue
		
		biggest_size = room.rect.get_area()
		biggest_room = room
	
	return biggest_room

func disable_temporarily():
	temporary_disable = true
	disable_timer.start()

func _on_DisableTimer_timeout():
	temporary_disable = false
