extends Node

export var is_menu : bool = false

const MIN_DIST_BETWEEN_PLAYERS : float = 20.0
const PREDEFINED_SHAPE_SCALE : float = 1.25

var player_scene = preload("res://scenes/body.tscn")
var menu_player_scene = preload("res://scenes/menu_body.tscn")

onready var map = get_node("/root/Main/Map")

var num_players : int = 0
var player_colors = []
var player_shapes = []

var bodies_per_player = []

var predefined_shapes = {}
var available_shapes = []

func activate():
	load_colors()
	load_predefined_shapes()
	
	if not is_menu:
		if GInput.get_player_count() <= 0:
			GInput.create_debugging_players()
		
		num_players = GInput.get_player_count()
		create_players()

func create_players():
	player_shapes = []
	player_shapes.resize(num_players)
	
	bodies_per_player = []
	bodies_per_player.resize(num_players)
	for i in range(num_players):
		bodies_per_player[i] = []
	
	for i in range(num_players):
		create_player(i)

func get_player_shape_frame(player_num : int):
	var shape_name = player_shapes[player_num]
	return GDict.shape_list[shape_name].frame

func create_menu_player(player_num : int):
	create_player(player_num)

func create_player(player_num : int):
	if player_shapes.size() <= player_num:
		player_shapes.resize(player_num+1)
	
	if bodies_per_player.size() <= player_num:
		bodies_per_player.resize(player_num+1)
		bodies_per_player[player_num] = []
	
	var player
	if is_menu:
		player = menu_player_scene.instance()
		player.get_node("Status").is_menu = true
	else:
		player = player_scene.instance()
	
	var rand_shape = available_shapes.pop_front()
	if G.make_all_players_round():
		rand_shape = 'circle'
	
	player_shapes[player_num] = rand_shape
	player.get_node("Shaper").set_starting_shape(rand_shape)
	player.get_node("Shaper").create_from_shape(GDict.shape_list[rand_shape].points, { 'type': rand_shape })
	
	var start_pos
	if is_menu:
		start_pos = 0.5*Vector2(1024,200)
	else:
		var room = map.route_generator.cur_path[0]
		start_pos = get_spread_out_position(room)
	
	player.set_position(start_pos)
	map.add_child(player)
	
	player.status.set_shape_name(rand_shape)
	player.status.set_player_num(player_num)

func get_spread_out_position(room):
	var start_pos = room.rect.get_real_pos()
	var max_dist = room.rect.get_real_size()
	
	var bad_choice = true
	var pos
	
	while bad_choice:
		pos = start_pos + Vector2(randf(), randf())*max_dist
		
		if (closest_dist_to_player(pos) < MIN_DIST_BETWEEN_PLAYERS):
			continue
		
		if map.get_tilemap_at_real_pos(pos) != -1:
			continue
		
		bad_choice = false
	
	return pos

func remove_furthest_body_of(p_num : int):
	var body_list = bodies_per_player[p_num]
	if body_list.size() <= 1: return
	
	# TO DO (Optional): if you only have one body, this SLICES that body instead?
	var furthest_body = null
	var lowest_room_index = INF
	var dist_in_room = INF
	for b in body_list:
		var my_index = b.room_tracker.get_cur_room().route.index
		var my_dist = b.room_tracker.get_dist_in_room()
		if my_index > lowest_room_index: continue
		
		if my_index == lowest_room_index:
			if my_dist >= dist_in_room:
				continue

		lowest_room_index = my_index
		furthest_body = b
		dist_in_room = my_dist
	
	furthest_body.status.delete()

func closest_dist_to_player(pos):
	var other_players = get_tree().get_nodes_in_group("Players")
	var min_dist = INF
	for p in other_players:
		var dist = (pos - p.get_global_position()).length()
		min_dist = min(min_dist, dist)
	
	return min_dist

func load_colors():
	var num_colors = 10
	var hue_step = 1.0 / num_colors
	
	var saturation = 1.0
	var value = 1.0
	
	for i in range(num_colors):
		var new_col = Color.from_hsv(i * hue_step, saturation, value)
		player_colors.append(new_col)

func load_predefined_shapes():
	var list = preload("res://scenes/predefined_shape_list.tscn").instance()
	for child in list.get_children():
		if not (child is CollisionPolygon2D): continue
		
		var key = child.name.to_lower()
		var val = scale_shape( Array(child.polygon) )

		GDict.shape_list[key].points = val
		available_shapes.append(key)
	
	available_shapes.shuffle()

# NOTE: Points are already around centroid, and shaper node will do that again anyway, so just scale only
func scale_shape(points):
	var new_points = []
	for p in points:
		new_points.append(p * PREDEFINED_SHAPE_SCALE)
	return new_points

func count_bodies_of_player(num):
	return bodies_per_player[num].size()

func register_body(p):
	p.add_to_group("Players")
	bodies_per_player[p.status.player_num].append(p)

func deregister_body(p):
	p.remove_from_group("Players")
	bodies_per_player[p.status.player_num].erase(p)
