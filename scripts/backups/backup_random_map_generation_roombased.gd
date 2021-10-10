extends Node2D

const WORLD_SIZE : Vector2 = Vector2(50, 30)
const TILE_DIMENSIONS : int = 6
const ROOM_SIZE : float = 64.0*TILE_DIMENSIONS
var map = []

var cur_path = []

var leading_player
var trailing_player

var player_scene = preload("res://scenes/body.tscn")

var rooms = [
	preload("res://rooms/room1.tscn")
]

func _ready():
	randomize()
	
	initialize_grid()
	initialize_rooms()
	
	
	
	var player = player_scene.instance()
	player.get_node("Shaper").create_from_random_shape()
	place_inside_room(cur_path[0], player)
	call_deferred("add_child", player)

func place_inside_room(pos, player):
	var room_pos = (cur_path[0] + Vector2(1,1)*0.5)*ROOM_SIZE
	player.set_position(room_pos)

func out_of_bounds(pos):
	return pos.x < 0 or pos.x >= WORLD_SIZE.x or pos.y < 0 or pos.y >= WORLD_SIZE.y

func initialize_grid():
	map = []
	map.resize(WORLD_SIZE.x)

	for x in range(WORLD_SIZE.x):
		map[x] = []
		map[x].resize(WORLD_SIZE.y)
		
		for y in range(WORLD_SIZE.y):
			var pos = Vector2(x,y)

			map[x][y] = {
				'pos': pos,
				'room': null
			}

func initialize_rooms():
	var num_rooms = 5
	for i in range(num_rooms):
		create_new_room()

func is_empty(pos):
	if out_of_bounds(pos): return false
	if map[pos.x][pos.y].room: return false
	return true

func get_room_pos_from_player(p):
	var pos = p.get_global_position()
	pos /= ROOM_SIZE
	pos = pos.floor()
	
	return pos

func _physics_process(dt):
	determine_leading_and_trailing_player()
	check_for_new_room()
	check_for_old_room_deletion()

func create_new_room():
	var new_pos = Vector2.ZERO
	var new_side = -1
	var cur_room = null
	
	# determine best new pos for new room
	# (get pos of last room, find free neighbor for that)
	if cur_path.size() > 0:
		var cur_last_pos = cur_path[cur_path.size() - 1]
		cur_room = map[cur_last_pos.x][cur_last_pos.y].room
		
		var nbs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
		var good_candidates = []

		for i in range(nbs.size()):
			var nb = nbs[i]
			var temp_pos = cur_last_pos + nb
			if not is_empty(temp_pos): continue
			
			good_candidates.append({ 'pos': temp_pos, 'side': i })

		var rand_candidate = good_candidates[randi() % good_candidates.size()]

		new_pos = rand_candidate.pos
		new_side = rand_candidate.side
	
	# Instantiate a (fitting) room scene
	var chosen_room = randi() % rooms.size()
	var room_scene = null
	
	if cur_room:
		var available_openings = cur_room.get_openings(new_side)
		var bad_choice = true
		while bad_choice:
			bad_choice = true
			
			chosen_room = randi() % rooms.size()
			var target_side = (new_side + 2) % 4
			
			room_scene = rooms[chosen_room].instance()
			room_scene.generate_openings()
			
			var chosen_openings = room_scene.get_openings(target_side)
			var res = any_match(available_openings, chosen_openings)
			if res > -1:
				room_scene.close_opening(target_side, res)
				cur_room.close_opening(new_side, res)
				cur_room.fill_all_gaps()
				bad_choice = false
			
			else:
				room_scene.queue_free()
	else:
		room_scene = rooms[chosen_room].instance()
		room_scene.generate_openings()

	var new_room = room_scene
	
	new_room.set_position(new_pos * ROOM_SIZE)
	
	cur_path.append(new_pos)
	map[new_pos.x][new_pos.y].room = new_room
	
	add_child(new_room)

func delete_oldest_room():
	var old_pos = cur_path.pop_front()
	var old_room = map[old_pos.x][old_pos.y].room
	
	old_room.queue_free()
	map[old_pos.x][old_pos.y].room = null

func check_for_new_room():
	if not leading_player: return
	
	var index = cur_path.find(get_room_pos_from_player(leading_player))
	var num_rooms_threshold = 3
	var far_enough_forward = (index > cur_path.size() - num_rooms_threshold)
	
	if far_enough_forward:
		create_new_room()

func check_for_old_room_deletion():
	if not trailing_player: return
	
	var index = cur_path.find(get_room_pos_from_player(trailing_player))
	var num_rooms_threshold = 2
	var far_enough_from_last_room = (index > num_rooms_threshold)
	
	if far_enough_from_last_room:
		delete_oldest_room()

func determine_leading_and_trailing_player():
	var max_room = -INF
	var min_room = INF
	
	var players = get_tree().get_nodes_in_group("Players")
	for p in players:
		var pos = get_room_pos_from_player(p)
		var index = cur_path.find(pos)
		
		if index > max_room:
			max_room = index
			leading_player = p
		
		if index < min_room:
			min_room = index
			trailing_player = p

func get_pos_just_ahead():
	if not leading_player: return Vector2.ZERO
	
	var index = cur_path.find(get_room_pos_from_player(leading_player))
	index += 1
	
	if index >= cur_path.size(): return leading_player.get_global_position()
	
	return cur_path[index]*ROOM_SIZE

func any_match(arr1, arr2):
	for a in arr1:
		for b in arr2:
			if a == b:
				return a
	
	return -1
