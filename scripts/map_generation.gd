extends Node2D

 # how many back rooms should stay on screen until they are DELETED
const NUM_ROOMS_BACK_BUFFER : int = 5

# how many rooms should be CREATED in front of the leading player
const NUM_ROOMS_FRONT_BUFFER : int = 5

const TILE_SIZE : float = 64.0
const WORLD_SIZE : Vector2 = Vector2(20, 10) # Vector2(50, 30)
var default_starting_pos = Vector2(0.5,0)*WORLD_SIZE
var map = []

var cur_path = []
var path_dirs = []

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

var test_player

####
#
# Initialization
#
####
func generate():
	randomize()
	
	$MaskPainter/TilemapTexture.size = WORLD_SIZE*TILE_SIZE
	
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
	for x in range(-1, WORLD_SIZE.x+1):
		change_cell(Vector2(x, -1), 0)
		change_cell(Vector2(x, WORLD_SIZE.y), 0)
	
	for y in range(-1, WORLD_SIZE.y+1):
		change_cell(Vector2(-1,y), 0)
		change_cell(Vector2(WORLD_SIZE.x,y), 0)

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

func get_cell(pos):
	return map[pos.x][pos.y]

func change_terrain_at(pos, type):
	get_cell(pos).terrain = type

# TO DO: Actually set to the given TYPE
# TO DO: Check if the other side actually exists (in both functions - add + remove)
func set_edge_at(pos, dir_index, type):
	var e = edge_scene.instance()
	var vec = get_vector_from_dir(dir_index)

	var edge_grid_pos = pos + 0.5*Vector2(1,1) + 0.5*vec
	e.set_position(edge_grid_pos*TILE_SIZE)
	e.set_rotation(dir_index * 0.5 * PI)
	
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

####
#
# Helpers
#
####
func get_random_grid_pos():
	return Vector2(randi() % int(WORLD_SIZE.x), randi() % int(WORLD_SIZE.y))

func get_real_pos(pos):
	return pos*TILE_SIZE

func keep_within_bounds(pos : Vector2) -> Vector2:
	if pos.x < 0: pos.x = 0
	if pos.x >= WORLD_SIZE.x: pos.x = WORLD_SIZE.x - 1
	
	if pos.y < 0: pos.y = 0
	if pos.y >= WORLD_SIZE.y: pos.y = WORLD_SIZE.y - 1
	
	return pos

func get_vector_from_dir(d):
	var angle = d*0.5*PI
	return Vector2(cos(angle), sin(angle))

func get_dir_from_vector(vec):
	var angle = vec.angle()
	var epsilon = 0.003
	return floor( (angle * 4) / 2*PI + epsilon )

func get_cell_from_node(node):
	var grid_pos = node.get_global_position() / float(TILE_SIZE)
	return get_cell(grid_pos)

func get_room_at(pos):
	return get_cell(pos).room

func set_room_at(pos, r):
	for x in range(r.size.x):
		for y in range(r.size.y):
			var new_pos = r.pos + Vector2(x,y)
			get_cell(new_pos).room = r

func out_of_bounds(pos):
	return pos.x < 0 or pos.x >= WORLD_SIZE.x or pos.y < 0 or pos.y >= WORLD_SIZE.y

func is_empty(pos):
	if out_of_bounds(pos): return false
	if not get_room_at(pos): return false
	return true

func get_cur_room_index(p : RigidBody2D) -> int:
	var pos = p.get_global_position()
	for i in range(cur_path.size()-1,-1,-1):
		var point = cur_path[i]
		var room = get_room_at(point)
		
		if room.has_point(pos):
			return i
	
	return -1

func get_path_from_front(offset : int = 0):
	var index = cur_path.size() - 1 - offset
	if index < 0: return null
	
	return get_room_at(cur_path[index])

func get_furthest_room():
	if cur_path.size() == 0: return null
	
	var pos = cur_path[cur_path.size() - 1]
	return get_room_at(pos)

func can_place_rectangle(r, ignore_room_index):
	for x in range(r.size.x):
		for y in range(r.size.y):
			var my_pos = r.pos + Vector2(x,y)
			if out_of_bounds(my_pos): return false
			
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
		if tilemap.get_cellv(new_pos) != params.id: continue
		
		res.append(new_pos)
	
	return res

# TO DO: Function can be simplified, as 0 == 2 and 1 == 3
func get_random_displacement(old_r, new_r, dir_index):
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
# Managing the tilemap
# (making it look pretty, adding slopes, making sure we choose the right tiles, etc.)
#
####

# TO DO: Shouldn't these be functions on the RECTANGLES themselves? Or at least partly?
func should_be_slope(pos):
	# an empty cell ...
	if tilemap.get_cellv(pos) != -1: return false
	
	# with precisely two neighbours ...
	var nbs = get_neighbor_tiles(pos, { 'id': 0 })
	if nbs.size() != 2: return false
	
	# who are at an angle ( = NOT opposite each other) ...
	var epsilon = 0.05
	if (nbs[0] - pos).dot(nbs[1] - pos) < -(1 - epsilon): return false
	
	# slope!
	return true

func is_slope(pos):
	return tilemap.get_cellv(pos) == 1

func check_for_slopes(r):
	var slopes_to_create = []
	
	# remove slopes that have become nonsensical
	for x in range(r.size.x):
		for y in range(r.size.y):
			var pos = r.pos + Vector2(x,y)

			if is_slope(pos) and not should_be_slope(pos):
				change_cell(pos, -1)
	
	# plan the creation of new slopes
	for x in range(r.size.x):
		for y in range(r.size.y):
			var pos = r.pos + Vector2(x,y)
			if not should_be_slope(pos): continue
			
			var nbs = get_neighbor_tiles(pos, { 'id': 0 })
			slopes_to_create.append({ 'pos': pos, 'nbs': nbs })
	
	# actually create the slopes AND rotate them correctly
	for s in slopes_to_create:
		var pos = s.pos
		var nbs = s.nbs
		
		var flip_x = false
		if (pos - nbs[0]).x > 0 or (pos - nbs[1]).x > 0: flip_x = true 
		
		var flip_y = false
		if (pos - nbs[0]).y > 0 or (pos - nbs[1]).y > 0: flip_y = true
		
		# @params => set_cellv (pos, id, flip_x, flip_y, transpose)
		change_cell(pos, 1, flip_x, flip_y)

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
		rand_rect.set_random_size(true)
	
	params.rect = rand_rect

# "Optional requirements" means that we WANT to do something at the earliest moment possible
# but if we're barely able to place rooms, just place a fitting room and postpone it until later
func set_wanted_room_parameters(params):
	params.place_finish = (total_rooms_created > rooms_until_finish)
	params.place_lock = (rooms_in_current_section > rooms_until_section_end)
	
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
	var smaller_room_try_threshold = 100
	var check_against_grown_rect_threshold = 100
	var max_tries = 200
	
	var base_pos = params.room.pos
	var first_room = (params.room_index == (cur_path.size() - 1))
	var bad_choice = true
	
	print("TRYING WITH BASE POS")
	print(base_pos)
	
	var rect = params.rect
	
	params.disallow_going_back = true
	params.overlapping_rooms_were_allowed = false
	
	while bad_choice and num_tries < max_tries:
		bad_choice = false
		
		rect.set_random_size(params.require_large_size)
		
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

		var dirs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
		var candidates = []
		
		var last_dir = path_dirs[path_dirs.size()-1]
		var opposite_to_last_dir = ((last_dir + 2) % 4)
		
		for i in range(dirs.size()):
			if params.disallow_going_back:
				if i == opposite_to_last_dir: continue
			
			var random_displacement = get_random_displacement(params.room, rect, i)

			var dir = dirs[i]
			var temp_pos = base_pos + dir * params.room.size + random_displacement
			
			if dir.x < 0 or dir.y < 0:
				temp_pos = base_pos + dir * rect.size + random_displacement
			
			rect.set_pos(temp_pos)
			
			var rect_to_check_against = rect
			var ignore_index = -1
			if num_tries < check_against_grown_rect_threshold:
				rect_to_check_against = rect.copy_and_grow(1)
				ignore_index = params.room_index
			else:
				# NOTE: if we don't grow the rectangle, we should NOT ignore
				# overlaps with ANY room, as that means an ACTUAL OVERLAP
				params.overlapping_rooms_were_allowed = true
			
			if not can_place_rectangle(rect_to_check_against, ignore_index): 
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
		
		params.pos = final_candidate.pos
		params.dir = final_candidate.dir_index
	
	params.no_valid_placement = (num_tries >= max_tries)

func place_room_according_to_params(params):
	var rect = params.rect
	
	rect.set_previous_room(params.room)
	rect.set_pos(params.pos)
	rect.erase_tiles()
	
	cur_path.append(params.pos)
	path_dirs.append(params.dir)
	set_room_at(params.pos, rect)
	
	var grown_rect = rect.copy_and_grow(1)
	check_for_slopes(grown_rect)
	
	if params.overlapping_rooms_were_allowed:
		rect.create_border_around_us()

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
		
		'overlapping_rooms_were_allowed': false
	}
	
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
	
	map[old_pos.x][old_pos.y].room = null

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
	if index == (cur_path.size()-1): return null
	
	var coming_positions : Vector2 = Vector2.ZERO
	var num_positions_considered : float = 0
	
	for i in range(index+1, cur_path.size()):
		var ratio : float = 1.0 / float(i-index)
		coming_positions += ratio * cur_path[index]*TILE_SIZE
		num_positions_considered += ratio
	
	coming_positions /= num_positions_considered
	
	return coming_positions

func delete_all_rooms():
	var num_rooms = cur_path.size()
	for i in range(num_rooms):
		delete_oldest_room()
