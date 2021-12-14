extends Node

 # how many back rooms should stay on screen until they are DELETED
const NUM_ROOMS_BACK_BUFFER : int = 4

# how many rooms should be CREATED (AT MOST) in front of the leading player
const NUM_ROOMS_FRONT_BUFFER : int = 25

# with how many pre-created rooms we start each game
const NUM_STARTING_ROOMS : int = 5

# the actual path of rooms, in order
var cur_path = []

# keep track of total room count, so we know when to finish
var total_rooms_created : int = 0
var rooms_until_finish : int = 0
var level_size_bounds : Vector2 = Vector2(200, 300) #Vector2(50, 60)
var has_finished : bool = false

# another tracker for when to place locks
var rooms_in_current_section : int = 0
var rooms_until_section_end : int = 0
var section_size_bounds : Vector2 = Vector2(30, 60) #Vector2(10, 20) 

# room generation is only paused when a teleporter has been placed
# (and we CAN'T continue, even if we wanted to
var pause_room_generation : bool = false

onready var map = get_parent()
onready var room_picker = get_node("../RoomPicker")
onready var player_progression = get_node("../PlayerProgression")
onready var edges = get_node("../Edges")
onready var mask_painter = get_node("../MaskPainter")

var create_phase : bool = false

#
# Initialization
#
func initialize_rooms():
	for _i in range(NUM_STARTING_ROOMS):
		room_picker.create_new_room()
	
	$Timer.wait_time = (1.0 / GlobalDict.cfg.generation_speed)
	$Timer.start()

func set_global_parameters():
	rooms_until_finish = int( floor(rand_range(level_size_bounds.x, level_size_bounds.y)))
	rooms_until_section_end = int( floor(rand_range(section_size_bounds.x, section_size_bounds.y)))

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
	
	var lead = player_progression.get_leading_player()
	var index = lead.get_node("RoomTracker").get_cur_room().route.index
	var num_rooms_threshold = NUM_ROOMS_FRONT_BUFFER
	var far_enough_forward = (index > cur_path.size() - num_rooms_threshold)
	
	if far_enough_forward:
		room_picker.create_new_room()

func check_for_old_room_deletion():
	if not player_progression.has_trailing_player(): return
	
	var trail = player_progression.get_trailing_player()
	var index = trail.get_node("RoomTracker").get_cur_room().route.index
	var num_rooms_threshold = NUM_ROOMS_BACK_BUFFER
	var far_enough_from_last_room = (index > num_rooms_threshold)
	
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
	rooms_in_current_section = 0
	rooms_until_section_end = int( floor(rand_range(section_size_bounds.x, section_size_bounds.y)))

#
# Queries into the route
#
func should_place_finish():
	return (total_rooms_created > rooms_until_finish)

func should_place_lock():
	 return (rooms_in_current_section > rooms_until_section_end)

func get_new_room_index():
	return cur_path.size()

# TO DO: 
# On big rooms, it might be faster to check against ROOMS, not individual cells???? Not sure if that is the case. (So check overlap with the other room rect, AABB, for all rooms on path.)
# NOTE: This gets a _rectangle_ not a _room_, so we can't go through rect.positions
func room_rect_overlaps_path(rect, params):
	for x in range(rect.size.x):
		for y in range(rect.size.y):
			var my_pos = rect.pos + Vector2(x,y)
			if map.out_of_bounds(my_pos): return true
			
			var cur_room = map.get_room_at(my_pos)
			
			if not cur_room: continue
			if cur_room.route.index == params.prev_room.route.index: continue
			
			return true
	return false

func get_cur_room(p : RigidBody2D):
	var pos = p.get_global_position()
	var grid_pos = (pos / map.TILE_SIZE).floor()
	return map.get_room_at(grid_pos)

func get_furthest_room():
	if cur_path.size() == 0: return null
	return cur_path[cur_path.size()-1]

func get_path_from_front(offset : int = 0):
	var index = cur_path.size() - 1 - offset
	if index < 0: return null
	
	return cur_path[index]

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
	var index = lead.get_node("RoomTracker").get_cur_room().route.index
	if index == (cur_path.size()-1): return null
	
	var coming_positions : Vector2 = Vector2.ZERO
	var num_positions_considered : float = 0
	
	var max_rooms_to_look_ahead = 3
	var max_bound = min(cur_path.size(), index+max_rooms_to_look_ahead)
	
	for i in range(index+1, max_bound):
		var ratio : float = 1.0 / float(i-index)
		coming_positions += ratio * cur_path[i].rect.get_center()
		num_positions_considered += ratio
	
	coming_positions /= num_positions_considered
	
	var max_look_ahead_euclidian = 400
	var vec = (coming_positions - lead.get_global_position())
	var norm_vec = vec.normalized()
	var dist = min(vec.length(), max_look_ahead_euclidian)
	
	return lead.get_global_position() + norm_vec*dist

func get_next_best_player(p):
	var my_index = p.get_node("RoomTracker").get_cur_room().route.index
	var my_num = p.get_node("Status").player_num
	for i in range(my_index+1, cur_path.size()):
		var room = cur_path[i]
		
		for p in room.entities.get_them():
			var num = p.get_node("Status").player_num
			if num == my_num: continue
			
			return p
	
	return player_progression.get_leading_player()
