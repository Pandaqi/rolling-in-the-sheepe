extends Node2D

 # how many back rooms should stay on screen until they are DELETED
const NUM_ROOMS_BACK_BUFFER : int = 5

# how many rooms should be CREATED in front of the leading player
const NUM_ROOMS_FRONT_BUFFER : int = 5

const TILE_SIZE : float = 64.0
const WORLD_SIZE : int = 30
var default_starting_pos = Vector2(0.5,0)*WORLD_SIZE
var map = []

var cur_path = []
var path_dirs = []

var leading_player
var trailing_player

var player_scene = preload("res://scenes/body.tscn")
var RoomRect = preload("res://scripts/RoomRect.gd")

var total_rooms_created : int = 0
var rooms_until_finish : int = 0
var level_size_bounds : Vector2 = Vector2(10, 20) #Vector2(100, 150)
var has_finished : bool = false

var rooms_in_current_section : int = 0
var rooms_until_section_end : int = 0
var section_size_bounds : Vector2 = Vector2(15, 30)

onready var tilemap = $TileMap
onready var tilemap_terrain = $TileMapTerrain

var test_player

####
#
# Initialization
#
####
func _ready():
	randomize()
	
	set_global_parameters()
	
	initialize_grid()
	initialize_rooms()
	
	place_test_player()

func place_test_player():
	var player = player_scene.instance()
	player.get_node("Shaper").create_from_random_shape()
	place_inside_room(cur_path[0], player)
	call_deferred("add_child", player)
	
	test_player = player

func place_inside_room(pos, player):
	var room = get_room_at(pos)
	player.set_position(room.get_center())

func initialize_grid():
	map = []
	map.resize(WORLD_SIZE)

	for x in range(WORLD_SIZE):
		map[x] = []
		map[x].resize(WORLD_SIZE)
		
		for y in range(WORLD_SIZE):
			var pos = Vector2(x,y)
			
			tilemap.set_cellv(pos, 0)
			
			map[x][y] = {
				'pos': pos,
				'terrain': null,
				'edges': [null, null, null, null],
				'room': null
			}
	
	# create an extra border around the world so we can never just go outside
	for x in range(-1, WORLD_SIZE+1):
		tilemap.set_cellv(Vector2(x, -1), 0)
		tilemap.set_cellv(Vector2(x, WORLD_SIZE), 0)
	
	for y in range(-1, WORLD_SIZE+1):
		tilemap.set_cellv(Vector2(-1,y), 0)
		tilemap.set_cellv(Vector2(WORLD_SIZE,y), 0)

func initialize_rooms():
	var num_rooms = 5
	for i in range(num_rooms):
		create_new_room()

func set_global_parameters():
	rooms_until_finish = floor(rand_range(level_size_bounds.x, level_size_bounds.y))
	rooms_in_current_section = floor(rand_range(section_size_bounds.x, section_size_bounds.y))

####
#
# Easily changing (or accessing) properties of cells
#
####
func change_terrain_at(pos, type):
	map[pos.x][pos.y].terrain = type

####
#
# Helpers
#
####
func get_cell_from_node(node):
	var grid_pos = node.get_global_position() / float(TILE_SIZE)
	return map[grid_pos.x][grid_pos.y]

func get_room_at(pos):
	return map[pos.x][pos.y].room

func set_room_at(pos, r):
	map[pos.x][pos.y].room = r

func out_of_bounds(pos):
	return pos.x < 0 or pos.x >= WORLD_SIZE or pos.y < 0 or pos.y >= WORLD_SIZE

func is_empty(pos):
	if out_of_bounds(pos): return false
	if not get_room_at(pos): return false
	return true

func get_cur_room_index(p : RigidBody2D) -> int:
	var pos = p.get_global_position()
	for i in range(cur_path.size()):
		var point = cur_path[i]
		var room = get_room_at(point)
		
		if room.has_point(pos):
			return i
	
	return -1

func get_furthest_room():
	if cur_path.size() == 0: return null
	
	var pos = cur_path[cur_path.size() - 1]
	return get_room_at(pos)

func can_place_rectangle(r):
	for x in range(r.size.x):
		for y in range(r.size.y):
			var my_pos = r.pos + Vector2(x,y)
			if out_of_bounds(my_pos): return false
			
			for their_pos in cur_path:
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
				tilemap.set_cellv(pos, -1)
	
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
		tilemap.set_cellv(pos, 1, flip_x, flip_y)

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
#
#	if test_player:
#		print(get_cur_room_index(test_player))

func create_new_room():
	var rand_rect = RoomRect.new()
	rand_rect.init(self, tilemap, tilemap_terrain)
	
	total_rooms_created += 1
	rooms_in_current_section += 1
	
	var place_finish = (total_rooms_created > rooms_until_finish)
	var place_lock = (rooms_in_current_section > rooms_until_section_end)
	
	var require_large_size = (place_finish or place_lock)
	
	# Keep trying to find an open spot
	# changing room SIZE and DISPLACEMENT ( = exact position) every time
	var final_candidate
	var new_pos = default_starting_pos
	var new_dir = 0
	
	var room = get_furthest_room()
	var num_tries = 0
	var max_tries = 1000
	
	
	if room:
		var base_pos = room.pos
		var bad_choice = true
		
		while bad_choice and num_tries < max_tries:
			bad_choice = false
			
			rand_rect.set_random_size(require_large_size)

			var dirs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
			var candidates = []
			
			var last_dir = path_dirs[path_dirs.size()-1]
			var opposite_to_last_dir = ((last_dir + 2) % 4)
			
			for i in range(dirs.size()):
				if i == opposite_to_last_dir: continue
				var random_displacement = get_random_displacement(room, rand_rect, i)

				var dir = dirs[i]
				var temp_pos = base_pos + dir * room.size + random_displacement
				
				if dir.x < 0 or dir.y < 0:
					temp_pos = base_pos + dir * rand_rect.size + random_displacement
				
				rand_rect.set_pos(temp_pos)
				
				if not can_place_rectangle(rand_rect): continue
				
				candidates.append({ 'dir': dir, 'pos': temp_pos, 'dir_index': i })
			
			if candidates.size() <= 0:
				bad_choice = true
				num_tries += 1
				continue
			
			final_candidate = candidates[randi() % candidates.size()]
			new_pos = final_candidate.pos
			new_dir = final_candidate.dir_index
	
	if num_tries >= max_tries:
		print("NO MORE PLACES TO GO => Place teleporter or end level")
		return
	
	rand_rect.set_pos(new_pos)
	rand_rect.erase_tiles()
	
	cur_path.append(new_pos)
	path_dirs.append(new_dir)
	set_room_at(new_pos, rand_rect)
	
	var grown_rect = rand_rect.copy_and_grow(1)
	check_for_slopes(grown_rect)
	
	if place_finish:
		has_finished = true
		rand_rect.paint_terrain("finish")
	
	elif place_lock:
		rand_rect.add_lock()
		
		rooms_in_current_section = 0
		rooms_until_section_end = floor(rand_range(section_size_bounds.x, section_size_bounds.y))

func delete_oldest_room():
	var old_pos = cur_path.pop_front()
	var old_room = get_room_at(old_pos)
	
	old_room.fill_tiles()
	
	map[old_pos.x][old_pos.y].room = null

func check_for_new_room():
	if not leading_player: return
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
	
	var players = get_tree().get_nodes_in_group("Players")
	for p in players:
		var index = get_cur_room_index(p)
		
		if index > max_room:
			max_room = index
			leading_player = p
		
		if index < min_room:
			min_room = index
			trailing_player = p

func get_pos_just_ahead():
	if not leading_player: return null
	
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
