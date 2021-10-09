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

var leading_player
var trailing_player

var player_scene = preload("res://scenes/body.tscn")

onready var tilemap = $TileMap

var test_player

var rooms = [
	preload("res://rooms/room1.tscn")
]

func _ready():
	randomize()
	
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
	var room = map[pos.x][pos.y].room
	var room_pos = (pos + Vector2(room.width, room.height)*0.5)*TILE_SIZE
	player.set_position(room_pos)

func out_of_bounds(pos):
	return pos.x < 0 or pos.x >= WORLD_SIZE or pos.y < 0 or pos.y >= WORLD_SIZE

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

func is_empty(pos):
	if out_of_bounds(pos): return false
	if map[pos.x][pos.y].room: return false
	return true

func point_in_rect(p, r):
	return p.x >= r.x and p.x <= (r.x+r.width) and p.y >= r.y and p.y <= (r.y+r.height)

func rectangles_overlap(a, b):
	return a.x < (b.x+b.width) and b.x < (a.x+a.width) and a.y < (b.y+b.height) and b.y < (a.y+a.height)

func convert_to_global(room):
	var new_room = {}
	
	new_room.x = room.x*TILE_SIZE
	new_room.y = room.y*TILE_SIZE
	new_room.width = room.width*TILE_SIZE
	new_room.height = room.height*TILE_SIZE
	
	return new_room

func erase_rectangle(r):
	change_rectangle_to(r, -1)

func fill_rectangle(r):
	change_rectangle_to(r, 0)

func change_rectangle_to(r, tile_id : int):
	for x in range(r.width):
		for y in range(r.height):
			var pos = Vector2(r.x, r.y) + Vector2(x,y)
			tilemap.set_cellv(pos, tile_id)

func get_cur_room_index(p : RigidBody2D) -> int:
	var pos = p.get_global_position()
	for i in range(cur_path.size()):
		var point = cur_path[i]
		var room = convert_to_global(map[point.x][point.y].room)
		
		if point_in_rect(pos, room):
			return i
	
	return -1

func get_furthest_room():
	if cur_path.size() == 0: return null
	
	var pos = cur_path[cur_path.size() - 1]
	return map[pos.x][pos.y].room

func can_place_rectangle(r):
	for x in range(r.width):
		for y in range(r.height):
			var my_pos = Vector2(r.x, r.y) + Vector2(x,y)
			if out_of_bounds(my_pos): return false
			
			for their_pos in cur_path:
				var other_room = map[their_pos.x][their_pos.y].room
				
				if rectangles_overlap(r, other_room): return false
	
	return true

func _physics_process(dt):
	determine_leading_and_trailing_player()
	check_for_new_room()
	check_for_old_room_deletion()
#
#	if test_player:
#		print(get_cur_room_index(test_player))

func get_random_displacement(old_r, new_r, dir_index):
	var epsilon = 0.1
	var ortho_dir = Vector2(0,1)
	if dir_index == 1 or dir_index == 3:
		ortho_dir = Vector2(1,0)
	
	# horizontal placement of rooms,
	# so displace vertically
	var bounds = { 'min': 0, 'max': 0 }
	if dir_index == 0 or dir_index == 2:
		bounds.min = -(new_r.height-1)
		bounds.max = old_r.height - 1
	
	else:
		bounds.min = -(new_r.width-1)
		bounds.max = old_r.width-1
	
	var rand_bound = randi() % int(bounds.max - bounds.min + 1) + bounds.min
	
	return ortho_dir * rand_bound

# TO DO: Should make this "rect" into an actual "room" script/class
#        I have the sense we'll need to extend it and use it often
func create_new_room():
	var rand_rect = { 'x': 0, 'y': 0, 'width': randi() % 3 + 1, 'height': randi() % 3 + 1}
	var new_pos = default_starting_pos
	
	# TO DO: When we can't find anything, change
	#  => Room SIZE
	#  => Room DISPLACEMENT
	var room = get_furthest_room()
	var num_tries = 0
	var max_tries = 1000
	
	if room:
		var base_pos = Vector2(room.x, room.y)
		var bad_choice = true
		
		while bad_choice and num_tries < max_tries:
			bad_choice = false
			
			rand_rect.width = randi() % 3 + 1
			rand_rect.height = randi() % 3 + 1
		
			var dirs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
			var candidates = []
			
			for i in range(3):
				var random_displacement = get_random_displacement(room, rand_rect, i)

				var dir = dirs[i]
				var temp_pos = base_pos + dir * Vector2(room.width, room.height) + random_displacement
				
				if dir.x < 0 or dir.y < 0:
					temp_pos = base_pos + dir * Vector2(rand_rect.width, rand_rect.height) + random_displacement
				
				rand_rect.x = temp_pos.x
				rand_rect.y = temp_pos.y
				
				if not can_place_rectangle(rand_rect): continue
				
				candidates.append({ 'dir': dir, 'pos': temp_pos })
			
			if candidates.size() <= 0:
				bad_choice = true
				num_tries += 1
				continue
			
			var rand_candidate = candidates[randi() % candidates.size()]
			new_pos = rand_candidate.pos
	
	if num_tries >= max_tries:
		print("NO MORE PLACES TO GO => Place teleporter or end level")
		return
	
	rand_rect.x = new_pos.x
	rand_rect.y = new_pos.y
	
	cur_path.append(new_pos)
	map[new_pos.x][new_pos.y].room = rand_rect
	
	erase_rectangle(rand_rect)
	
	var grown_rect = grow_rectangle(rand_rect, 1)
	check_for_slopes(grown_rect)

# Slopes are made on
#  => Empty cells
#  => With two neighbors
#  => Which are NOT opposite each other
func check_for_slopes(r):
	var epsilon = 0.05
	var slopes_to_create = []
	
	# remove slopes that have become nonsensical
	for x in range(r.width):
		for y in range(r.height):
			var pos = Vector2(r.x, r.y) + Vector2(x,y)
			if tilemap.get_cellv(pos) != 1: continue
			
			var nbs = get_neighbor_tiles(pos, { 'id': 0 })
			if nbs.size() != 2: 
				tilemap.set_cellv(pos, -1)
				continue
			
			if (nbs[0] - pos).dot(nbs[1] - pos) >= -(1 - epsilon):
				tilemap.set_cellv(pos, -1)
				continue
	
	# create new slopes
	for x in range(r.width):
		for y in range(r.height):
			var pos = Vector2(r.x, r.y) + Vector2(x,y)
			
			if tilemap.get_cellv(pos) != -1: continue
			
			var nbs = get_neighbor_tiles(pos, { 'id': 0 })
			if nbs.size() != 2: continue
			
			if (nbs[0] - pos).dot(nbs[1] - pos) < -(1 - epsilon): continue
			
			slopes_to_create.append({ 'pos': pos, 'nbs': nbs })
	
	# TO DO: rotate slopes correctly
	# (use s.nbs, the neighbor array)
	for s in slopes_to_create:
		# set_cellv (pos, id, flip_x, flip_y, transpose)
		var pos = s.pos
		var nbs = s.nbs
		
		var flip_x = false
		if (pos - nbs[0]).x > 0 or (pos - nbs[1]).x > 0: flip_x = true 
		
		var flip_y = false
		if (pos - nbs[0]).y > 0 or (pos - nbs[1]).y > 0: flip_y = true
		
		tilemap.set_cellv(pos, 1, flip_x, flip_y)

func get_neighbor_tiles(pos, params):
	var nbs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	var res = []
	for nb in nbs:
		var new_pos = pos + nb
		if tilemap.get_cellv(new_pos) != params.id: continue
		
		res.append(new_pos)
	
	return res

func grow_rectangle(rect, val):
	return {
		'x': rect.x-val,
		'y': rect.y-val,
		'width': rect.width+2*val,
		'height': rect.height+2*val
	}

func delete_oldest_room():
	var old_pos = cur_path.pop_front()
	var old_room = map[old_pos.x][old_pos.y].room
	
	fill_rectangle(old_room)
	
	map[old_pos.x][old_pos.y].room = null

func check_for_new_room():
	if not leading_player: return
	
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
	if not leading_player: return Vector2.ZERO
	
	var index = get_cur_room_index(leading_player)
	
	var coming_positions = Vector2.ZERO
	var num_positions_considered = 0
	for i in range(index+1, cur_path.size()):
		var ratio =  1 / float(i-index)
		coming_positions += ratio * cur_path[index]*TILE_SIZE
		num_positions_considered += ratio
	
	coming_positions /= num_positions_considered
	
	return coming_positions
