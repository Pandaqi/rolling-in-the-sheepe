extends Node2D

 # how many back rooms should stay on screen until they are DELETED
const NUM_ROOMS_BACK_BUFFER : int = 5

# how many rooms should be CREATED in front of the leading player
const NUM_ROOMS_FRONT_BUFFER : int = 5

const TILE_SIZE : float = 64.0
const WORLD_SIZE : Vector2 = Vector2(50, 30)
const BORDER_THICKNESS : int = 5

var default_starting_pos = Vector2(0.5,0)*WORLD_SIZE
var default_starting_room_size = Vector2(5,5)
var default_room_size_for_tutorial = Vector2(2,2)

var map = []
var cur_path = []

var leading_player
var trailing_player

var edge_scene = preload("res://scenes/edge.tscn")

var RoomRect = preload("res://scripts/RoomRect.gd")

var pause_room_generation : bool = false

var total_rooms_created : int = 0
var rooms_until_finish : int = 0
var level_size_bounds : Vector2 = Vector2(200, 300)
var has_finished : bool = false

var rooms_in_current_section : int = 0
var rooms_until_section_end : int = 0
var section_size_bounds : Vector2 = Vector2(30, 60)

onready var tilemap = $TileMap
onready var tilemap_copy = $MaskPainter/TilemapTexture/TileMapCopy
onready var tilemap_terrain = $TileMapTerrain
onready var mask_painter = $MaskPainter
onready var tutorial = get_node("/root/Main/Tutorial")

var test_player

####
#
# Initialization
#
####
func generate():
	randomize()
	
	$MaskPainter/TilemapTexture.size = WORLD_SIZE*TILE_SIZE
	
	if tutorial.is_active():
		default_starting_room_size = Vector2(6, 2)
	
	set_global_parameters()
	
	initialize_grid()
	initialize_rooms()

func place_inside_room(pos):
	var room = get_room_at(pos)
	return room.get_center()

func initialize_grid():
	map = []
	map.resize(WORLD_SIZE.x)

	for x in range(WORLD_SIZE.x):
		map[x] = []
		map[x].resize(WORLD_SIZE.y)
		
		for y in range(WORLD_SIZE.y):
			var pos = Vector2(x,y)
			
			change_cell(pos, 0)
			
			map[x][y] = {
				'pos': pos,
				'terrain': null,
				'edges': [null, null, null, null],
				'room': null,
			}
	
	# create an extra border around the world so we can never just go outside
	var border_size = BORDER_THICKNESS
	for x in range(-border_size, WORLD_SIZE.x+border_size):
		for y in range(border_size):
			change_cell(Vector2(x, -1-y), 0)
			change_cell(Vector2(x, WORLD_SIZE.y + y), 0)
	
	for y in range(-border_size, WORLD_SIZE.y+border_size):
		for x in range(border_size):
			change_cell(Vector2(-1-x,y), 0)
			change_cell(Vector2(WORLD_SIZE.x + x,y), 0)

func get_full_dimensions():
	return {
		'x': -BORDER_THICKNESS * TILE_SIZE,
		'y': -BORDER_THICKNESS * TILE_SIZE,
		'width': (WORLD_SIZE.x+(BORDER_THICKNESS*2)) * TILE_SIZE,
		'height': (WORLD_SIZE.y+(BORDER_THICKNESS*2)) * TILE_SIZE
	}

func initialize_rooms():
	var num_rooms = 5
	for i in range(num_rooms):
		create_new_room()

func set_global_parameters():
	rooms_until_finish = floor(rand_range(level_size_bounds.x, level_size_bounds.y))
	rooms_until_section_end = floor(rand_range(section_size_bounds.x, section_size_bounds.y))

####
#
# Easily changing (or accessing) properties of cells
#
####
func change_cell(pos, id, flip_x = false, flip_y = false, transpose = false):
	tilemap.set_cellv(pos, id, flip_x, flip_y, transpose)
	tilemap_copy.set_cellv(pos, id, flip_x, flip_y, transpose)

func update_bitmask(pos, size):
	var update_margin = Vector2(1,1)
	tilemap.update_bitmask_region(pos-update_margin, size+update_margin*2)
	tilemap_copy.update_bitmask_region(pos-update_margin, size+update_margin*2)

func get_cell(pos):
	return map[pos.x][pos.y]

func get_tilemap_at_real_pos(pos):
	var grid_pos = (pos / TILE_SIZE).floor()
	return tilemap.get_cellv(grid_pos)

func change_terrain_at(pos, type):
	if out_of_bounds(pos): return
	get_cell(pos).terrain = type

# TO DO: Actually implement the "set_type" function on edge.gd
func set_edge_at(pos, dir_index, type):
	var already_has_edge = get_cell(pos).edges[dir_index]
	if already_has_edge:
		already_has_edge.set_type(type)
		return
	
	var e = edge_scene.instance()
	var vec = get_vector_from_dir(dir_index)

	var edge_grid_pos = pos + 0.5*Vector2(1,1) + 0.5*vec
	e.set_position(edge_grid_pos*TILE_SIZE)
	e.set_rotation(dir_index * 0.5 * PI)
	e.set_type(type)
	
	get_cell(pos).edges[dir_index] = e
	
	add_child(e)
	
	var other_side = vec
	if out_of_bounds(pos+other_side): return
	
	var other_dir_index = (dir_index + 2) % 4
	get_cell(pos+other_side).edges[other_dir_index] = e

func remove_edge_at(pos, dir_index):
	var other_pos = pos + get_vector_from_dir(dir_index)
	var other_dir_index = (dir_index + 2) % 4
	
	if not get_cell(pos).edges[dir_index]: return
	
	get_cell(pos).edges[dir_index].queue_free()
	get_cell(pos).edges[dir_index] = null
	
	if out_of_bounds(other_pos): return
	
	get_cell(other_pos).edges[other_dir_index].queue_free()
	get_cell(other_pos).edges[other_dir_index] = null

func remove_all_edges_at(pos):
	for i in range(4):
		remove_edge_at(pos, i)

####
#
# Managing the tilemap
# (making it look pretty, adding slopes, making sure we choose the right tiles, etc.)
#
####

# TO DO: Shouldn't these be functions on the RECTANGLES themselves? Or at least partly?
func should_be_slope(pos):
	# an empty cell ...
	if tilemap.get_cellv(pos) != -1: return false

	# a cell with precisely two neighbours ...
	var nbs = get_neighbor_tiles(pos, { 'filled': true })
	if nbs.size() != 2: return false
	
	# who are at an angle ( = NOT opposite each other) ...
	var epsilon = 0.05
	if (nbs[0] - pos).dot(nbs[1] - pos) < -(1 - epsilon): return false
	
	# slope!
	return true

func check_for_slopes(r):
	var slopes_to_create = []
	
	# plan the creation of new slopes
	for x in range(r.size.x):
		for y in range(r.size.y):
			var pos = r.pos + Vector2(x,y)
			if not should_be_slope(pos): continue
			
			slopes_to_create.append(pos)
	
	for pos in slopes_to_create:
		#if randf() <= 0.5: continue
		change_cell(pos, 0)

	update_bitmask(r.pos, r.size)
	
	var allowed_slopes = [Vector2(0,0), Vector2(1,0), Vector2(3,0), Vector2(8,0), Vector2(11,0), Vector2(0,2), Vector2(1,2), Vector2(3,2), Vector2(1,3), Vector2(3,3), Vector2(8,3), Vector2(11,3)]
	
	var something_changed = false
	for pos in slopes_to_create:
		var tile_coord = tilemap.get_cell_autotile_coord(pos.x, pos.y)
		
		var good_slope = false
		for a in allowed_slopes:
			if (tile_coord - a).length() <= 0.03:
				good_slope = true
				break
		
		if not good_slope:
			change_cell(pos, -1)
			something_changed = true
	
	if something_changed:
		update_bitmask(r.pos, r.size)
	

####
#
# Helpers
#
####
func get_random_grid_pos():
	return Vector2(randi() % int(WORLD_SIZE.x), randi() % int(WORLD_SIZE.y))

func get_real_pos(pos):
	return pos*TILE_SIZE

func keep_within_bounds(pos : Vector2, allow_edge_overlap = false) -> Vector2:
	if pos.x < 0: pos.x = 0
	if pos.x >= WORLD_SIZE.x: 
		pos.x = WORLD_SIZE.x - 1
		if allow_edge_overlap: pos.x = WORLD_SIZE.x
	
	if pos.y < 0: pos.y = 0
	if pos.y >= WORLD_SIZE.y: 
		pos.y = WORLD_SIZE.y - 1
		if allow_edge_overlap: pos.y = WORLD_SIZE.y
	
	return pos

func get_vector_from_dir(d):
	var angle = d*0.5*PI
	return Vector2(cos(angle), sin(angle))

func get_dir_from_vector(vec):
	var angle = vec.angle()
	var epsilon = 0.003
	return floor( (angle * 4) / 2*PI + epsilon )

func get_cell_from_node(node):
	var grid_pos = (node.get_global_position() / float(TILE_SIZE)).floor()
	if out_of_bounds(grid_pos): return get_cell(Vector2.ZERO)
	return get_cell(grid_pos)

func get_room_at(pos):
	return get_cell(pos).room

func set_room_at(pos, r):
	for x in range(r.size.x):
		for y in range(r.size.y):
			var new_pos = r.pos + Vector2(x,y)
			get_cell(new_pos).room = r

# If negative or 0, we're inside the world area (and not out of bounds)
# If positive, gives us the number of tiles we're out of bounds
func dist_to_bounds(pos):
	var x = max(0 - pos.x, pos.x - (WORLD_SIZE.x - 1))
	var y = max(0 - pos.y, pos.y - (WORLD_SIZE.y - 1))
	return max(x,y)

func out_of_bounds(pos):
	return pos.x < 0 or pos.x >= WORLD_SIZE.x or pos.y < 0 or pos.y >= WORLD_SIZE.y

func is_empty(pos):
	if out_of_bounds(pos): return false
	if not get_room_at(pos): return false
	return true

func get_cur_room(p : RigidBody2D, return_index = false):
	var pos = p.get_global_position()
	for i in range(cur_path.size()-1,-1,-1):
		var point = cur_path[i]
		var room = get_room_at(point)
		
		if room.has_real_point(pos):
			if return_index: return i
			return room
	
	if return_index:
		return -1
	return null

func get_cur_room_index(p : RigidBody2D) -> int:
	return get_cur_room(p, true)

# TO DO: Might be more worthwhile to REGISTER which players are inside each room
# (So I can just loop through cur_path, starting from player, until I find a room with players inside.)
# These steps need to be taken => on the map reader, any time we change cell, we also check if we changed room (and register ourselves properly)
func get_next_best_player(p):
	var players = get_tree().get_nodes_in_group("Players")
	
	var my_num = p.get_node("Status").player_num
	var my_index = get_cur_room_index(p)
	
	var best_index = INF
	var best_player = null
	
	for other_player in players:
		var num = other_player.get_node("Status").player_num
		if num == my_num: continue
		
		var index = get_cur_room_index(other_player)
		if index <= my_index: continue
		
		if index < best_index:
			best_player = other_player
		
		best_index = min(best_index, index)
	
	return best_player

func get_path_from_front(offset : int = 0):
	var index = cur_path.size() - 1 - offset
	if index < 0: return null
	
	return get_room_at(cur_path[index])

func get_furthest_room():
	if cur_path.size() == 0: return null
	
	var pos = cur_path[cur_path.size() - 1]
	return get_room_at(pos)

func can_place_rectangle(r, ignore_room_index, growth_area : int = 0):
	for x in range(r.size.x):
		for y in range(r.size.y):
			var my_pos = r.pos + Vector2(x,y)
			
			# if the rectangle was GROWN, the REAL rectangle might still be inside the bounds, so ignore if the pos is inside this buffer
			if dist_to_bounds(my_pos) > growth_area: 
				return false
			
			for i in range(cur_path.size()):
				if i == ignore_room_index: continue
				
				var their_pos = cur_path[i]
				var other_room = get_room_at(their_pos)
				
				if r.overlaps(other_room): return false
	
	return true

func get_neighbor_tiles(pos, params):
	var nbs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	var res = []
	for nb in nbs:
		var new_pos = pos + nb
		var tile_data = tilemap.get_cellv(new_pos)
		
		if params.has('id'):
			if tile_data != params.id: continue
		
		if params.has('filled'):
			if tile_data < 0: continue
		
		res.append(new_pos)
	
	return res

# TO DO: Function can be simplified, as 0 == 2 and 1 == 3
func get_random_displacement(old_r, new_r, dir_index):
	if tutorial.is_active():
		return Vector2.ZERO
	
	var epsilon = 0.1
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

####
#
# Frame update; check every frame
# Concerned with deleting old rooms and creating new ones
#
####
func _physics_process(dt):
	determine_leading_and_trailing_player()
	check_for_new_room()
	check_for_old_room_deletion()

func initialize_new_room_rect(params):
	var rand_rect = RoomRect.new()
	rand_rect.init(self, tilemap, tilemap_terrain)
	
	var first_room = (cur_path.size() == 0)
	if first_room:
		rand_rect.set_size(default_starting_room_size)
	
	params.rect = rand_rect

# "Optional requirements" means that we WANT to do something at the earliest moment possible
# but if we're barely able to place rooms, just place a fitting room and postpone it until later
func set_wanted_room_parameters(params):
	params.place_finish = (total_rooms_created > rooms_until_finish)
	params.place_lock = (rooms_in_current_section > rooms_until_section_end)
	
	if tutorial.is_active(): 
		params.place_lock = false
	
	params.require_large_size = (params.place_finish or params.place_lock)
	
	params.ignore_optional_requirements = false
	params.no_valid_placement = false

func find_valid_configuration(params):
	# Keep trying to find an open spot
	# changing room SIZE and DISPLACEMENT ( = exact position) every time
	var final_candidate
	var new_pos = default_starting_pos
	var new_dir = 0
	
	var num_tries = 0
	var smaller_room_try_threshold = 150
	var check_against_grown_rect_threshold = 150
	var forced_dir_try_threshold = 190 #NOTE: Must be HIGHER than the others, otherwise it's very hard to do a zigzag and go back early (just too little space)
	var max_tries = 200
	
	var base_pos = params.room.pos
	var first_room = (params.room_index == (cur_path.size() - 1))
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
				ignore_index = params.room_index
				growth_val = 1
			else:
				# NOTE: if we don't grow the rectangle, we should NOT ignore
				# overlaps with ANY room, as that means an ACTUAL OVERLAP
				params.overlapping_rooms_were_allowed = true
			
			if not can_place_rectangle(rect_to_check_against, ignore_index, growth_val): 
				continue
			
			# make horizontal movements more probable
			var weight : int = 1
			if i == 0 or i == 2:
				weight = 3
			
			for w in range(weight):
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
	rect.set_pos(params.pos)
	
	rect.set_previous_room(params.room)
	rect.set_dir(params.dir)
	rect.set_path_position(total_rooms_created)
	
	var handout_terrains = (not tutorial.is_active())
	if handout_terrains:
		rect.give_terrain_if_wanted()
	rect.erase_tiles()
	
	cur_path.append(params.pos)
	set_room_at(params.pos, rect)
	
	# NOTE: We check slopes on the PREVIOUS room
	# Because NOW we know the connections and can make a sensible placement
	
	if params.room:
		var grown_rect = params.room
		check_for_slopes(grown_rect)

	if params.overlapping_rooms_were_allowed:
		rect.create_border_around_us()
	
	var wanted_tut = tutorial.wanted_tutorial_placement
	if wanted_tut:
		var can_place_it = params.require_large_size
		if can_place_it:
			tutorial.place_image(rect, tilemap)

func handle_optional_requirements(params):
	if params.ignore_optional_requirements: return
	
	if params.place_finish:
		has_finished = true
		params.rect.paint_terrain("finish")
		
	elif params.place_lock:
		params.rect.add_lock()
		
		rooms_in_current_section = 0
		rooms_until_section_end = floor(rand_range(section_size_bounds.x, section_size_bounds.y))

func update_global_generation_parameters(params):
	total_rooms_created += params.rect.get_longest_side()
	rooms_in_current_section += params.rect.get_longest_side()

func create_new_room(proposed_location : Vector2 = Vector2.ZERO):
	if pause_room_generation: return
	
	var room = get_furthest_room()
	var params = {
		'pos': default_starting_pos,
		'dir': 0,
		'room': room,
		'room_index': cur_path.size() - 1,
		
		'overlapping_rooms_were_allowed': false,
		'forced_dir': -1,
	}
	
	if tutorial.is_active(): params.forced_dir = tutorial.get_forced_dir()
	if proposed_location: params.pos = proposed_location
	
	initialize_new_room_rect(params)
	set_wanted_room_parameters(params)
	
	if room: 
		# allow backtracking = trying earlier and earlier rooms if the others yield nothing
		for i in range(NUM_ROOMS_FRONT_BUFFER):
			params.room_index = cur_path.size() - 1 - i
			params.room = get_path_from_front(i)
			find_valid_configuration(params)
			
			if not params.no_valid_placement: break
	
	if params.no_valid_placement:
		pause_room_generation = true
		get_furthest_room().turn_into_teleporter()
		return
	
	place_room_according_to_params(params)
	handle_optional_requirements(params)
	
	update_global_generation_parameters(params)

func delete_oldest_room():
	var old_pos = cur_path.pop_front()
	var old_room = get_room_at(old_pos)
	
	old_room.delete()

func check_for_new_room():
	if not leading_player or not is_instance_valid(leading_player): return
	if pause_room_generation: return
	if has_finished: return
	
	var index = get_cur_room_index(leading_player)
	var num_rooms_threshold = NUM_ROOMS_FRONT_BUFFER
	var far_enough_forward = (index > cur_path.size() - num_rooms_threshold)
	
	if far_enough_forward:
		create_new_room()

func check_for_old_room_deletion():
	if not trailing_player: return
	
	var index = get_cur_room_index(trailing_player)
	var num_rooms_threshold = NUM_ROOMS_BACK_BUFFER
	var far_enough_from_last_room = (index > num_rooms_threshold)
	
	if far_enough_from_last_room:
		delete_oldest_room()

func determine_leading_and_trailing_player():
	var max_room = -INF
	var min_room = INF
	
	leading_player = null
	trailing_player = null
	
	var players = get_tree().get_nodes_in_group("Players")
	for p in players:
		if not is_instance_valid(p): continue
		
		var index = get_cur_room_index(p)
		
		if index > max_room:
			max_room = index
			leading_player = p
		
		if index < min_room:
			min_room = index
			trailing_player = p

func on_body_sliced(b):
	if b == leading_player:
		leading_player = null
	
	elif b == trailing_player:
		trailing_player = null

func get_pos_just_ahead():
	if not leading_player or not is_instance_valid(leading_player): return null
	
	var index = get_cur_room_index(leading_player)
	if index == (cur_path.size()-1): return leading_player.get_global_position()
	
	var coming_positions : Vector2 = Vector2.ZERO
	var num_positions_considered : float = 0
	
	var max_rooms_to_look_ahead = 4
	var max_bound = min(cur_path.size(), index+max_rooms_to_look_ahead+15)
	
	for i in range(index+1, max_bound):
		var ratio : float = 1.0 / float(i-index)
		coming_positions += ratio * cur_path[i]*TILE_SIZE
		num_positions_considered += ratio
	
	coming_positions /= num_positions_considered
	
	return coming_positions

func delete_all_rooms():
	# delete all the rooms
	while cur_path.size() > 0:
		delete_oldest_room()
	
	# delete all the edges
	for x in range(WORLD_SIZE.x):
		for y in range(WORLD_SIZE.y):
			remove_all_edges_at(Vector2(x,y))
	
	# clear the painting mask
	mask_painter.clear_mask()
