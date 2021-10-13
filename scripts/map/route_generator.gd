extends Node2D

 # how many back rooms should stay on screen until they are DELETED
const NUM_ROOMS_BACK_BUFFER : int = 5

# how many rooms should be CREATED in front of the leading player
const NUM_ROOMS_FRONT_BUFFER : int = 5

# with how many pre-created rooms we start each game
const NUM_STARTING_ROOMS : int = 5

# the actual path of rooms, in order
var cur_path = []

# keep track of total room count, so we know when to finish
var total_rooms_created : int = 0
var rooms_until_finish : int = 0
var level_size_bounds : Vector2 = Vector2(200, 300)
var has_finished : bool = false

# another tracker for when to place locks
var rooms_in_current_section : int = 0
var rooms_until_section_end : int = 0
var section_size_bounds : Vector2 = Vector2(30, 60)

# room generation is only paused when a teleporter has been placed
# (and we CAN'T continue, even if we wanted to
var pause_room_generation : bool = false

onready var map = get_parent()
onready var room_picker = get_node("../RoomPicker")
onready var player_progression = get_node("../PlayerProgression")
onready var edges = get_node("../Edges")
onready var mask_painter = get_node("../MaskPainter")

#
# Initialization
#
func initialize_rooms():
	for _i in range(NUM_STARTING_ROOMS):
		room_picker.create_new_room()

func set_global_parameters():
	rooms_until_finish = int( floor(rand_range(level_size_bounds.x, level_size_bounds.y)))
	rooms_until_section_end = int( floor(rand_range(section_size_bounds.x, section_size_bounds.y)))

#
# Every frame update; core of algorithm (delete old rooms, add new)
#
func _physics_process(_dt):
	check_for_new_room()
	check_for_old_room_deletion()

func check_for_new_room():
	if not player_progression.has_leading_player(): return
	if pause_room_generation: return
	if has_finished: return
	
	var lead = player_progression.get_leading_player()
	var index = lead.get_node("RoomTracker").get_cur_room().index
	var num_rooms_threshold = NUM_ROOMS_FRONT_BUFFER
	var far_enough_forward = (index > cur_path.size() - num_rooms_threshold)
	
	if far_enough_forward:
		room_picker.create_new_room()

func check_for_old_room_deletion():
	if not player_progression.has_trailing_player(): return
	
	var trail = player_progression.get_trailing_player()
	var index = trail.get_node("RoomTracker").get_cur_room().index
	var num_rooms_threshold = NUM_ROOMS_BACK_BUFFER
	var far_enough_from_last_room = (index > num_rooms_threshold)
	
	if far_enough_from_last_room:
		delete_oldest_room()

func delete_oldest_room():
	cur_path.pop_front().delete()
	
	# update the index of all surviving rooms
	# (should be lowered by exactly one, for all)
	for i in range(cur_path.size()):
		cur_path[i].set_index(i)

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

func can_place_rectangle(r, ignore_room_index, growth_area : int = 0):
	for x in range(r.size.x):
		for y in range(r.size.y):
			var my_pos = r.pos + Vector2(x,y)
			
			# if the rectangle was GROWN, the REAL rectangle might still be inside the bounds, so ignore if the pos is inside this buffer
			if map.dist_to_bounds(my_pos) > growth_area: 
				return false
			
			for i in range(cur_path.size()):
				if i == ignore_room_index: continue
				if r.overlaps(cur_path[i]): return false
	
	return true

func get_cur_room(p : RigidBody2D):
	var pos = p.get_global_position()
	for i in range(cur_path.size()-1,-1,-1):
		var room = cur_path[i]
		
		if room.has_real_point(pos):
			return room

	return null

func get_furthest_room():
	if cur_path.size() == 0: return null
	return cur_path[cur_path.size()-1]

func get_path_from_front(offset : int = 0):
	var index = cur_path.size() - 1 - offset
	if index < 0: return null
	
	return cur_path[index]

func get_pos_just_ahead():
	if not player_progression.has_leading_player(): return null
	
	var lead = player_progression.get_leading_player()
	var index = lead.get_node("RoomTracker").get_cur_room().index
	if index == (cur_path.size()-1): 
		return lead.get_global_position()
	
	var coming_positions : Vector2 = Vector2.ZERO
	var num_positions_considered : float = 0
	
	var max_rooms_to_look_ahead = 4
	var max_bound = min(cur_path.size(), index+max_rooms_to_look_ahead+15)
	
	for i in range(index+1, max_bound):
		var ratio : float = 1.0 / float(i-index)
		coming_positions += ratio * cur_path[i].get_center()
		num_positions_considered += ratio
	
	coming_positions /= num_positions_considered
	
	return coming_positions

func get_next_best_player(p):
	var my_index = p.get_node("RoomTracker").get_cur_room().index
	var my_num = p.get_node("Status").player_num
	for i in range(my_index+1, cur_path.size()):
		var room = cur_path[i]
		
		for p in room.players_inside:
			var num = p.get_node("Status").player_num
			if num == my_num: continue
			
			return p
	
	return player_progression.get_leading_player()
