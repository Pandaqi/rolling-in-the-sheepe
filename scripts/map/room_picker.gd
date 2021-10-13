extends Node2D

const MAX_BACKTRACK_ROOMS : int = 5

var default_starting_pos = Vector2(0.5,0)
var default_starting_room_size = Vector2(5,5)
var default_room_size_for_tutorial = Vector2(2,2)

onready var map = get_parent()
onready var route_generator = get_node("../RouteGenerator")
onready var tutorial = get_node("/root/Main/Tutorial")
onready var slope_painter = get_node("/root/Main/Map/SlopePainter")

var RoomRect = preload("res://scripts/RoomRect.gd")

#
# Initialization
#
func _ready():
	default_starting_pos *= map.WORLD_SIZE
	
	if tutorial.is_active():
		default_starting_room_size = Vector2(6, 2)

#
# The only functionality it has: create newest room
#
func create_new_room(proposed_location : Vector2 = Vector2.ZERO):
	var room = route_generator.get_furthest_room()
	
	var params = {
		'pos': default_starting_pos,
		'dir': 0,
		'room': room,
		
		'overlapping_rooms_were_allowed': false,
		'forced_dir': -1,
	}
	
	if tutorial.is_active(): params.forced_dir = tutorial.get_forced_dir()
	if proposed_location: params.pos = proposed_location
	
	initialize_new_room_rect(params)
	set_wanted_room_parameters(params)
	
	if room: 
		# allow backtracking = trying earlier and earlier rooms if the others yield nothing
		for i in range(MAX_BACKTRACK_ROOMS):
			params.room = route_generator.get_path_from_front(i)
			find_valid_configuration(params)
			
			if not params.no_valid_placement: break
	
	if params.no_valid_placement:
		route_generator.pause_room_generation = true
		route_generator.get_furthest_room().turn_into_teleporter()
		return
	
	place_room_according_to_params(params)
	handle_optional_requirements(params)
	
	update_global_generation_parameters(params)

#
# Implementation of the "create new room" functionality
#
func initialize_new_room_rect(params):
	var rand_rect = RoomRect.new()
	
	rand_rect.init(map)
	rand_rect.set_size(default_starting_room_size)
	
	params.rect = rand_rect

# "Optional requirements" means that we WANT to do something at the earliest moment possible
# but if we're barely able to place rooms, just place a fitting room and postpone it until later
func set_wanted_room_parameters(params):
	params.place_finish = route_generator.should_place_finish()
	params.place_lock = route_generator.should_place_lock()
	
	if tutorial.is_active(): params.place_lock = false
	
	params.require_large_size = (params.place_finish or params.place_lock)
	
	params.ignore_optional_requirements = false
	params.no_valid_placement = false

func find_valid_configuration(params):
	# Keep trying to find an open spot
	# changing room SIZE and DISPLACEMENT ( = exact position) every time
	var final_candidate
	
	var num_tries = 0
	var smaller_room_try_threshold = 150
	var check_against_grown_rect_threshold = 150
	var forced_dir_try_threshold = 190 #NOTE: Must be HIGHER than the others, otherwise it's very hard to do a zigzag and go back early (just too little space)
	var max_tries = 200
	
	var base_pos = params.room.pos
	var bad_choice = true

	var rect = params.rect
	
	params.disallow_going_back = true
	params.overlapping_rooms_were_allowed = false
	params.disallow_long_verticals = true
	
	var forced_dir_exists = (params.forced_dir >= 0)
	
	if tutorial.wanted_tutorial_placement:
		params.require_large_size = true
	
	while bad_choice and num_tries < max_tries:
		bad_choice = false
		
		rect.set_random_size(params.require_large_size)
		
		if forced_dir_exists and tutorial.is_active():
			rect.set_size(default_room_size_for_tutorial)
		
		# when we're out of space (mostly)
		# try 1-wide, very long rooms for a while
		# (they'll most likely fit AND get us out of trouble)
		if num_tries > smaller_room_try_threshold:
			var ratio = 1.0 - (num_tries - smaller_room_try_threshold) / float(max_tries - smaller_room_try_threshold)
			var long_side = round( max(5 * ratio, 1) )
			
			rect.set_size(Vector2(1,long_side))
			if randf() <= 0.5:
				rect.set_size(Vector2(long_side,1))
			
			params.disallow_going_back = false
			params.ignore_optional_requirements = true
			params.require_large_size = false

		var dirs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
		
		var candidates = []
		
		var last_dir = params.room.dir
		var opposite_to_last_dir = ((last_dir + 2) % 4)
		
		for i in range(dirs.size()):
			if params.disallow_going_back:
				if i == opposite_to_last_dir: 
					continue
			
			if params.disallow_long_verticals:
				if last_dir == 1 or last_dir == 3:
					if i == 1 or i == 3:
						continue
			
			var random_displacement = get_random_displacement(params.room, rect, i)

			var dir = dirs[i]
			var temp_pos = base_pos + dir * params.room.size + random_displacement
			
			if dir.x < 0 or dir.y < 0:
				temp_pos = base_pos + dir * rect.size + random_displacement
			
			rect.set_pos(temp_pos)
			
			var rect_to_check_against = rect
			var ignore_index = -1
			var growth_val = 0
			if num_tries < check_against_grown_rect_threshold:
				rect_to_check_against = rect.copy_and_grow(1)
				ignore_index = params.room.index
				growth_val = 1
			else:
				# NOTE: if we don't grow the rectangle, we should NOT ignore
				# overlaps with ANY room, as that means an ACTUAL OVERLAP
				params.overlapping_rooms_were_allowed = true
			
			if not route_generator.can_place_rectangle(rect_to_check_against, ignore_index, growth_val): 
				continue
			
			# make horizontal movements more probable
			var weight : int = 1
			if i == 0 or i == 2:
				weight = 3
			
			for _w in range(weight):
				candidates.append({ 'dir': dir, 'pos': temp_pos, 'dir_index': i })
		
		if candidates.size() <= 0:
			bad_choice = true
			num_tries += 1
			continue
		
		final_candidate = candidates[randi() % candidates.size()]
		
		# if a forced direction was specified
		# search for a candidate that matches and pick that one
		var able_to_match_forced_dir = false
		if forced_dir_exists:
			for c in candidates:
				if c.dir_index == params.forced_dir:
					final_candidate = c
					able_to_match_forced_dir = true
					tutorial.record_forced_dir_match()
					break
			
		if forced_dir_exists and not able_to_match_forced_dir:
			if num_tries < forced_dir_try_threshold:
				bad_choice = true
				num_tries += 1
				continue
			else:
				tutorial.forced_dir_exhausted()
		
		params.pos = final_candidate.pos
		params.dir = final_candidate.dir_index
	
	params.no_valid_placement = (num_tries >= max_tries)

func place_room_according_to_params(params):
	var rect = params.rect
	
	# NOTE: VERY IMPORTANT to do this first, before doing anything else
	# Otherwise the rect still has the default position and all calculations are wrong
	rect.set_index(route_generator.get_new_room_index())
	rect.set_pos(params.pos)
	
	rect.set_previous_room(params.room)
	rect.set_dir(params.dir)
	rect.set_path_position(route_generator.total_rooms_created)
	
	var handout_terrains = (not tutorial.is_active())
	if handout_terrains:
		rect.give_terrain_if_wanted()
	rect.erase_tiles()
	
	route_generator.cur_path.append(rect)
	map.set_all_cells_to_room(rect)
	
	# NOTE: We check slopes on the PREVIOUS room
	# Because NOW we know the connections and can make a sensible placement
	
	if params.room:
		var grown_rect = params.room
		slope_painter.check_for_slopes(grown_rect)

	if params.overlapping_rooms_were_allowed:
		rect.create_border_around_us()
	
	tutorial.placed_a_new_room(rect)

func handle_optional_requirements(params):
	if params.ignore_optional_requirements: return
	
	if params.place_finish:
		route_generator.placed_finish()
		params.rect.paint_terrain("finish")
		
	elif params.place_lock:
		route_generator.placed_lock()
		params.rect.add_lock()

func update_global_generation_parameters(params):
	route_generator.total_rooms_created += params.rect.get_longest_side()
	route_generator.rooms_in_current_section += params.rect.get_longest_side()

# TO DO: Function can be simplified, as 0 == 2 and 1 == 3
func get_random_displacement(old_r, new_r, dir_index):
	if tutorial.is_active():
		return Vector2.ZERO
	
	var ortho_dir = Vector2(0,1)
	if dir_index == 1 or dir_index == 3:
		ortho_dir = Vector2(1,0)
	
	# horizontal placement of rooms,
	# so displace vertically
	var bounds = { 'min': 0, 'max': 0 }
	if dir_index == 0 or dir_index == 2:
		bounds.min = -(new_r.size.y-1)
		bounds.max = old_r.size.y - 1
	
	else:
		bounds.min = -(new_r.size.x-1)
		bounds.max = old_r.size.x-1
	
	var rand_bound = randi() % int(bounds.max - bounds.min + 1) + bounds.min
	
	return ortho_dir * rand_bound
