extends Node

const DIST_BEFORE_PLACING_TELEPORTER : int = 4

const MAX_BACKTRACK_ROOMS : int = 10

# [0,1] => 0 = only largest rooms possible, 1 = only smallest rooms posible
const ROUTE_TIGHTNESS : float = 0.4

var default_starting_pos = Vector2(0.5,0)
var default_starting_room_size = Vector2(5,5)
var default_room_size_for_tutorial = Vector2(2,2)

onready var map = get_parent()
onready var route_generator = get_node("../RouteGenerator")
onready var player_progression = get_node("../PlayerProgression")
onready var tutorial = get_node("/root/Main/Tutorial")
onready var slope_painter = get_node("/root/Main/Map/SlopePainter")

var RoomRect = preload("res://scripts/RoomRect.gd")

#
# Initialization
#
func _ready():
	default_starting_pos *= map.WORLD_SIZE
	
	if tutorial.is_active():
		default_starting_room_size = Vector2(6, 4)

#
# The only functionality it has: create newest room
#
func create_new_room(proposed_location : Vector2 = Vector2.ZERO):
	var params = initialize_new_room_rect(proposed_location)
	set_wanted_room_parameters(params)
	
	# if we have a previous room, take it into account when placing the next
	# (allow backtracking if we keep failing)
	backtrack_and_find_good_room(params)

	if params.no_valid_placement:
		var should_place_teleporter = (player_progression.get_distance_to_generation_end() <= DIST_BEFORE_PLACING_TELEPORTER)
		if should_place_teleporter:
			route_generator.pause_room_generation = true
			route_generator.get_furthest_room().turn_into_teleporter()
		return
	
	place_room_according_to_params(params)
	handle_optional_requirements(params)
	
	update_global_generation_parameters(params)

#
# Implementation of the "create new room" functionality
#
func initialize_new_room_rect(proposed_location):
	var room = route_generator.get_furthest_room()
	
	var params = {
		'dir': 0,
		'room': room,
		
		'overlapping_rooms_were_allowed': false,
		'forced_dir': -1,
	}
	
	if tutorial.is_active(): params.forced_dir = tutorial.get_forced_dir()
	
	var pos = default_starting_pos
	if proposed_location: pos = proposed_location

	var rect = RoomRect.new()
	
	rect.init(map)
	rect.set_pos(pos)
	rect.set_size(default_starting_room_size)
	
	params.rect = rect
	
	return params

# "Optional requirements" means that we WANT to do something at the earliest moment possible
# but if we're barely able to place rooms, just place a fitting room and postpone it until later
func set_wanted_room_parameters(params):
	params.place_finish = route_generator.should_place_finish()
	params.place_lock = route_generator.should_place_lock()
	
	if tutorial.is_active(): params.place_lock = false
	
	params.require_large_size = (params.place_finish or params.place_lock)
	
	params.ignore_optional_requirements = false
	params.no_valid_placement = false

func backtrack_and_find_good_room(params):
	if not params.room: return # no previous room? no need to do all this
	
	var found_something = false
	for i in range(MAX_BACKTRACK_ROOMS):
		params.room = route_generator.get_path_from_front(i)
		
		var new_rect = find_valid_configuration_better(params)
		if not new_rect: continue
		
		found_something = true
		params.rect.set_pos(new_rect.pos)
		params.rect.set_size(new_rect.size)
		break
	
	if not found_something:
		params.no_valid_placement = true

func generate_all_1x1_rooms_in_dir(params):
	var dir_vertical = (params.dir == 1 or params.dir == 3)
	var arr = []
	var prev_room = params.room.shrunk
	
	if dir_vertical:
		var y_offset = -1 if params.dir == 3 else prev_room.size.y
		for x in range(prev_room.size.x):
			var temp_pos = prev_room.pos + Vector2(x, y_offset)
			arr.append({ 'pos': temp_pos, 'size': Vector2(1,1) })
	
	else:
		var x_offset = -1 if params.dir == 2 else prev_room.size.x
		for y in range(prev_room.size.y):
			var temp_pos = prev_room.pos + Vector2(x_offset, y)
			arr.append({ 'pos': temp_pos, 'size': Vector2(1,1) })
	
	return arr

func find_valid_configuration_better(params):
	# UPGRADE: controlled variation; determine our maximum size
	# (the path tries to stay varied: never too many small or large rooms after each other)
	var average_size_over_path : float = route_generator.get_average_room_size_over_last(7)
	var total_max_room_size : float = 7.0
	var rand_max : int = 0
	for i in range(1, total_max_room_size):
		rand_max = i
		if randf() <= ROUTE_TIGHTNESS * (average_size_over_path/total_max_room_size): break
	
	var max_room_size = Vector2(1,1)*rand_max
	
	# determine the preferred order in which to check directions
	# (it's a rolling game, so continuing horizontal is always best)
	var last_pos = params.room.shrunk.pos
	var last_size = params.room.shrunk.size
	var last_dir = params.room.dir
	var last_step_was_vertical = (last_dir == 1 or last_dir == 3)
	if last_step_was_vertical:
		last_dir = 0 if randf() < 0.5 else 2
	
	# UPGRADE: remove the direction towards edge, if we're close to it
	var preferred_dir_order = [last_dir, (last_dir + 2) % 4, 1, 3]
	if abs(map.dist_to_bounds(last_pos)) < total_max_room_size:
		preferred_dir_order.erase(map.dir_index_to_bounds(last_pos))
	
	# find the valid rooms in each dir, until we have a direction with results
	while preferred_dir_order.size() > 0:
		
		params.dir = preferred_dir_order.pop_front()
		
		var is_horizontal = (params.dir == 0 or params.dir == 2)
		var is_back_room = (params.dir == 2 or params.dir == 3)
		
		# UPGRADE: sneak peek
		# (try one big room in the direction)
		var sneak_room = { 'pos': last_pos, 'size': max_room_size }
		if params.dir == 0:
			sneak_room.pos += Vector2(last_size.x, 0)
		elif params.dir == 1:
			sneak_room.pos += Vector2(0, last_size.y)
		elif params.dir == 2: 
			sneak_room.pos -= Vector2(max_room_size.x,0)
		else: 
			sneak_room.pos -= Vector2(0, max_room_size.y)
		
		sneak_room.pos += get_random_displacement(last_size, max_room_size, params.dir)
		if not route_generator.room_overlaps_path(sneak_room, params):
			return sneak_room
		
		# start with all possible 1x1 rooms
		var valid_rooms = []
		var rooms_to_check = generate_all_1x1_rooms_in_dir(params)
		
		# when a new size level has started; we only want to return rooms from the LAST size level ( = the biggest)
		var cur_biggest_size = 0
		var new_size_level_index = -1
		
		while rooms_to_check.size() > 0:
			# if the room is bad, stop here
			var room = rooms_to_check.pop_front()
			if route_generator.room_overlaps_path(room, params):
				continue
			
			# otherwise, record it as valid
			valid_rooms.append(room)
			
			# and remember if we reached a new height (we only pick the biggest selection of rooms at the end)
			var total_size = room.size.x * room.size.y
			if total_size > cur_biggest_size:
				cur_biggest_size = total_size
				new_size_level_index = valid_rooms.size() - 1
			
			# if it's already maximum size, don't create any grown versions anymore
			if room.size.x >= max_room_size.x or room.size.y >= max_room_size.y:
				continue
			
			# and now add a GROWN version to the future rooms to check
			# (rooms grown in parallel to side need no further modification)
			# (rooms grown orthogonally also need an offset variant, as MORE displacement is possible)
			var extra_offset = Vector2.ZERO
			if is_horizontal:
				if is_back_room:
					extra_offset = Vector2(-1,0)
				
				rooms_to_check.append({ 'pos': room.pos + extra_offset, 'size': room.size + Vector2(1,0) })
				rooms_to_check.append({ 'pos': room.pos, 'size': room.size + Vector2(0,1) })
				
				if (room.pos.y == last_pos.y):
					rooms_to_check.append({ 'pos': room.pos - Vector2(0,1), 'size': room.size + Vector2(0,1) })
			
			else:
				if is_back_room:
					extra_offset = Vector2(0,-1)
				
				rooms_to_check.append({ 'pos': room.pos + extra_offset, 'size': room.size + Vector2(0,1) })
				rooms_to_check.append({ 'pos': room.pos, 'size': room.size + Vector2(1,0) })
				
				if (room.pos.x == last_pos.x):
					rooms_to_check.append({ 'pos': room.pos - Vector2(1,0), 'size': room.size + Vector2(1,0) })
		
		if valid_rooms.size() <= 0: continue
		
		# pick randomly from the LAST part of the array, as those are the BIGGER rooms, and then we're done
		var min_index = new_size_level_index
		var max_index = valid_rooms.size()
		var rand_index = randi() % (max_index - min_index) + min_index
		
		return valid_rooms[rand_index]
	
	return null

func place_room_according_to_params(params):
	var rect = params.rect
	
	# we AUTO-GROW rooms by 1 when saving them in the map (and painting terrain)
	# This ensures we also get a good background on slopes and other "transparent" autotiles
	# And also (hopefully) ensures betters separation of rooms
	rect.shrunk = { 'pos': rect.pos, 'size': rect.size }
	rect.set_pos(rect.pos - Vector2(1,1))
	rect.set_size(rect.size + Vector2(1,1)*2)
	
#	print("RECT PLACED")
#	print({ 'pos': rect.pos, 'size': rect.size })
#	print(rect.shrunk)

	rect.set_index(route_generator.get_new_room_index())
	
	rect.set_previous_room(params.room)
	rect.set_dir(params.dir)
	rect.set_path_position(route_generator.total_rooms_created)
	
	map.terrain.on_new_rect_created(rect)
	rect.erase_tiles()
	
	route_generator.cur_path.append(rect)
	map.set_all_cells_to_room(rect)

	# first recalculate tiles/slopes on previous room, which allows us to also place special elements
	slope_painter.recalculate_room(params.room)
	map.special_elements.add_special_items_to_room(params.room)
	map.edges.handle_gates(params.room)
	
	# then fill the new room
	slope_painter.place_slopes(rect)
	slope_painter.fill_room(rect)

	rect.determine_outline()
	
	#rect.determine_tiles_inside() => moved to when we actually place special elements, as then we KNOW what's inside and what's not
	# rect.create_border_around_us()
	
	tutorial.placed_a_new_room(rect)

func handle_optional_requirements(params):
	if params.ignore_optional_requirements: return
	
	var room_area = params.rect.get_area()
	if room_area < 9:
		params.place_finish = false
		params.place_lock = false
	
	if params.place_finish:
		route_generator.placed_finish()
		map.terrain.paint(params.rect, "finish")
		
	elif params.place_lock:
		route_generator.placed_lock()
		params.rect.add_lock()
	
	else:
		params.rect.can_have_special_items = true

func update_global_generation_parameters(params):
	route_generator.total_rooms_created += params.rect.get_longest_side()
	route_generator.rooms_in_current_section += params.rect.get_longest_side()

# TO DO: Can function be simplified, as 0 == 2 and 1 == 3???
func get_displacement_bounds(old_r, new_r, dir_index):
	# horizontal placement of rooms,
	# so displace vertically
	var bounds = { 'min': 0, 'max': 0 }
	if dir_index == 0 or dir_index == 2:
		bounds.min = -(new_r.y-1)
		bounds.max = old_r.y - 1
	
	else:
		bounds.min = -(new_r.x-1)
		bounds.max = old_r.x-1
	
	return bounds

func get_random_displacement(old_r, new_r, dir_index):
	var ortho_dir = Vector2(0,1)
	if dir_index == 1 or dir_index == 3:
		ortho_dir = Vector2(1,0)
	
	var bounds = get_displacement_bounds(old_r, new_r, dir_index)
	var rand_bound = randi() % int(bounds.max - bounds.min + 1) + bounds.min
	
	return ortho_dir * rand_bound
