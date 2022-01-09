extends Node

# If number of options below <threshold>, we pretend there are no options with probability <prob>
const PREEMPTIVE_TELEPORTER_THRESHOLD : int = 3
const PREEMPTIVE_TELEPORTER_PROB : float = 0.5 # unused atm

const DIST_BEFORE_PLACING_TELEPORTER : int = 4

const MAX_BACKTRACK_ROOMS : int = 7

# [0,1] => 0 = only largest rooms possible, 1 = only smallest rooms posible
const ROUTE_TIGHTNESS : float = 0.4

var default_starting_pos = Vector2(0.5,0)
var default_starting_room_size = Vector2(5,5)
var default_room_size_for_tutorial = Vector2(2,2)

onready var map = get_parent()
onready var route_generator = get_node("../RouteGenerator")
onready var player_progression = get_node("../PlayerProgression")
onready var slope_painter = get_node("/root/Main/Map/SlopePainter")

var room_scene = preload("res://scenes/room.tscn")

var tutorial_course_scene = preload("res://scenes/tutorial_course.tscn")
var tutorial_course = null

#
# Initialization
#
func _ready():
	default_starting_pos *= map.WORLD_SIZE
	
	if G.in_tutorial_mode():
		tutorial_course = tutorial_course_scene.instance()
		add_child(tutorial_course)

#
# The only functionality it has: create newest room
#
func create_new_room(proposed_location : Vector2 = Vector2.ZERO):
	if map.route_generator.generation_disallowed(): return
	
	var params = initialize_new_room_rect(proposed_location)
	set_wanted_room_parameters(params)
	
	# if we have a previous room, take it into account when placing the next
	# (allow backtracking if we keep failing)
	backtrack_and_find_good_room(params)
	var res = place_teleporter_if_stuck(params)
	if res: return

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
		'prev_room': room,
		'new_room': null,
		
		'overlapping_rooms_were_allowed': false,
		'forced_dir': -1,
		
		'place_finish': false,
		'place_lock': false,
		
		'require_large_size': false,
		'ignore_optional_requirements': false,
		'no_valid_placement': false
	}
	
	if randf() <= 0.5: params.dir = 2
	if G.in_tutorial_mode(): params.dir = 0 # left to right is easier/more intuitive for most people
	
	var pos = default_starting_pos
	if proposed_location: pos = proposed_location

	var new_room = room_scene.instance()
	add_child(new_room)
	new_room.initialize(pos, default_starting_room_size)
	params.new_room = new_room

	return params

# "Optional requirements" means that we WANT to do something at the earliest moment possible
# but if we're barely able to place rooms, just place a fitting room and postpone it until later
func set_wanted_room_parameters(params):
	params.place_finish = route_generator.should_place_finish()
	params.place_lock = route_generator.should_place_lock()
	
	# UPGRADE: no two locks directly after each other
	if params.prev_room and params.prev_room.lock.has_lock_or_planned():
		params.place_lock = false
	
	# EXCEPTION: in tutorial course, we delay locks until we've explained them
	if tutorial_course and not tutorial_course.can_place_locks:
		params.place_lock = false
	
	# if we need a lock, but we don't have any taught yet
	# forbid it, but place a tutorial for a lock at the nearest opportunity
	var wanted_tut_kind = 'any'
	if params.place_lock and not map.dynamic_tutorial.has_random('lock'):
		params.place_lock = false
		wanted_tut_kind = 'lock'
	
	params.place_tutorial = false
	
	if map.dynamic_tutorial.can_teach_something_new():
		map.dynamic_tutorial.plan_random_placement(wanted_tut_kind)
	
	params.place_tutorial = map.dynamic_tutorial.needs_tutorial()

	params.require_large_size = (params.place_finish or params.place_lock or params.place_tutorial)
	
	params.ignore_optional_requirements = false
	params.no_valid_placement = false

func backtrack_and_find_good_room(params):
	if not params.prev_room: return # no previous room? no need to do all this
	
	var found_something = false
	var max_backtracking = MAX_BACKTRACK_ROOMS
	if G.in_tutorial_mode(): max_backtracking = 2
	max_backtracking = min(max_backtracking, route_generator.cur_path.size())
	
	# NOTE: The first check (with the locks) is extremely important!
	# At first, it was wrong (also checked our own room), causing teleporters to be placed _every time a lock tried to be placed_, which is BAD
	
	for i in range(max_backtracking):
		# if the room of the previous iteration was a lock, we're not allowed to go past that (as it would defeat the purpose of locks)
		if i > 0 and params.prev_room.lock.has_lock_or_planned(): break
		
		params.prev_room = route_generator.get_path_from_front(i)

		var new_rect = find_valid_configuration_better(params)
		if not new_rect: continue
		
		found_something = true
		params.new_room.rect.update_from(new_rect)
		
		if i > 0: params.prev_room.is_backtrack = true
		
		break
	
	params.no_valid_placement = (not found_something)

func place_teleporter_if_stuck(params):
	if not params.no_valid_placement: return false
	
#	var should_place_teleporter = (player_progression.get_distance_to_generation_end() <= DIST_BEFORE_PLACING_TELEPORTER)
#	if not should_place_teleporter: return false
	
	print("TELEPORTER PLACED (because stuck)")
	
	# destroy the bad room we ended up not using
	params.new_room.queue_free()
	
	route_generator.pause_room_generation = true
	route_generator.get_ideal_teleporter_room().turn_into_teleporter()
	return true

func generate_all_1x1_rooms_in_dir(params):
	var dir_vertical = (params.dir == 1 or params.dir == 3)
	var arr = []
	var prev_rect = params.prev_room.rect.get_shrunk()
	
	if dir_vertical:
		var y_offset = -1 if params.dir == 3 else prev_rect.size.y
		for x in range(prev_rect.size.x):
			var temp_pos = prev_rect.pos + Vector2(x, y_offset)
			arr.append({ 'pos': temp_pos, 'size': Vector2(1,1) })
	
	else:
		var x_offset = -1 if params.dir == 2 else prev_rect.size.x
		for y in range(prev_rect.size.y):
			var temp_pos = prev_rect.pos + Vector2(x_offset, y)
			arr.append({ 'pos': temp_pos, 'size': Vector2(1,1) })
	
	return arr

func find_valid_configuration_better(params):
	var use_simple_generation = tutorial_course and tutorial_course.simple_route_generation
	var allow_preemptive_teleporter = (route_generator.cur_path.size() > 6) and not use_simple_generation and not G.in_tutorial_mode() and GDict.cfg.allow_preemptive_teleporter_placement
	
	# UPGRADE: controlled variation; determine our maximum size
	# (the path tries to stay varied: never too many small or large rooms after each other)
	var average_size_over_path : float = route_generator.get_average_room_size_over_last(7)
	var total_max_room_size : float = 7.0
	var rand_max : int = 0
	for i in range(1, total_max_room_size):
		rand_max = i
		if randf() <= ROUTE_TIGHTNESS * (average_size_over_path/total_max_room_size): break
	
	if use_simple_generation: rand_max = 3
	
	var max_room_size = Vector2(1,1)*rand_max
	
	# determine the preferred order in which to check directions
	# (it's a rolling game, so continuing horizontal is always best)
	var last_pos = params.prev_room.rect.shrunk.pos
	var last_size = params.prev_room.rect.shrunk.size
	var last_dir = params.prev_room.route.dir
	var last_step_was_vertical = (last_dir == 1 or last_dir == 3)
	if last_step_was_vertical:
		last_dir = 0 if randf() < 0.5 else 2
	
	# UPGRADE: remove the direction towards edge, if we're close to it
	var preferred_dir_order = [last_dir, (last_dir + 2) % 4, 1, 3]
	if abs(map.dist_to_bounds(last_pos)) < total_max_room_size:
		for d in map.dir_indices_to_bounds(last_pos, total_max_room_size):
			preferred_dir_order.erase(d)
	
	# UPGRADE: sneak peeks (explained further below)
	var allow_sneak_rooms = GDict.cfg.route_generation_sneak_improvement
	
	# EXCEPTION: tutorial wants to stay simple, so no upward
	if use_simple_generation:
		preferred_dir_order.erase(3)
	
	# find the valid rooms in each dir, until we have a direction with results
	var total_num_valid_rooms : int = 0
	var best_room_we_have
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
		if allow_sneak_rooms and (not route_generator.room_rect_overlaps_path(sneak_room, params)):
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
			if route_generator.room_rect_overlaps_path(room, params):
				continue
			
			# simple generation wants rooms to stay the same size
			if use_simple_generation:
				if params.dir == 0 or params.dir == 2:
					if room.size.x != last_size.x: continue
				elif params.dir == 1 or params.dir == 3:
					if room.size.y != last_size.y: continue
			
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
		
		total_num_valid_rooms += valid_rooms.size()
		
		if valid_rooms.size() <= 0: continue

		# pick randomly from the LAST part of the array, as those are the BIGGER rooms, and then we're done
		if not best_room_we_have:
			var min_index = new_size_level_index
			var max_index = valid_rooms.size()
			var rand_index = randi() % (max_index - min_index) + min_index
			
			best_room_we_have = valid_rooms[rand_index]
		
		# if we're low on options, continue to see if we can find more
		if allow_preemptive_teleporter and valid_rooms.size() <= PREEMPTIVE_TELEPORTER_THRESHOLD: 
			continue
		
		# otherwise: we found a room, break it
		break
	
	if total_num_valid_rooms < 3*PREEMPTIVE_TELEPORTER_THRESHOLD and allow_preemptive_teleporter:
		return null
	
	return best_room_we_have

func place_room_according_to_params(params):
	params.index = route_generator.get_new_room_index()
	params.path_pos = route_generator.total_rooms_created

	route_generator.cur_path.append(params.new_room)
	params.new_room.place(params)
	
	if params.prev_room:
		params.prev_room.finish_placement_in_hindsight()
	
	# EXCEPTION: first room doesn't know yet which way it's going, so we need to set that afterwards (once we have the second room)
	# TO DO: probably better to find a more elegant solution for that?
	if route_generator.cur_path.size() == 2:
		route_generator.cur_path[0].route.dir = route_generator.cur_path[1].route.dir
	
	params.new_room.finish_placement()
	map.dynamic_tutorial.on_room_placed()

func handle_optional_requirements(params):
	if params.ignore_optional_requirements: return
	
	var room_area = params.new_room.rect.get_area()
	if room_area < 9:
		params.place_finish = false
		params.place_lock = false
	
	if not params.new_room.rect.big_enough_for_tutorial():
		params.place_tutorial = false
	
	if params.place_finish:
		params.new_room.turn_into_finish()
		
	elif params.place_lock:
		params.new_room.lock.plan()
	
	elif params.place_tutorial:
		map.dynamic_tutorial.place_tutorial(params.new_room)
	
	else:
		params.new_room.items.allow()

func update_global_generation_parameters(params):
	route_generator.total_rooms_created += params.new_room.rect.get_longest_side()
	route_generator.rooms_in_current_section += params.new_room.rect.get_longest_side()
	
	if tutorial_course:
		tutorial_course.on_new_room_created(params.new_room)

func has_tutorial():
	return (tutorial_course != null)

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
