extends Node

export var is_menu : bool = false

const MIN_DIST_BETWEEN_PLAYERS : float = 20.0
const PREDEFINED_SHAPE_SCALE : float = 1.1

var player_scene = preload("res://scenes/body.tscn")
var menu_player_scene = preload("res://scenes/menu_body.tscn")

onready var main_node = get_parent()
onready var map = get_node("/root/Main/Map")
onready var particles = get_node("/root/Main/Particles")
onready var feedback = get_node("/root/Main/Feedback")

var num_players : int = 0
var player_colors = []
var player_shapes = []

var bodies_per_player = []

var predefined_shapes = {}
var available_shapes = []
var available_starting_shapes = []

func activate():
	load_colors()
	load_predefined_shapes()
	
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
		for a in range(GDict.cfg.num_starting_bodies):
			if is_menu:
				create_menu_player(i)
			else:
				create_player(i)

func get_player_starting_shape(player_num : int):
	return player_shapes[player_num]

func get_player_shape_frame(player_num : int):
	var shape_name = player_shapes[player_num]
	return GDict.shape_list[shape_name].frame

func create_menu_player(player_num : int):
	create_player(player_num)
	main_node.on_player_logged_in()

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
	
	var rand_shape = available_starting_shapes.pop_front()
	if G.make_all_players_round():
		rand_shape = 'circle'
	
	player_shapes[player_num] = rand_shape
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
	
	var starting_coins = GDict.cfg.num_starting_coins
	if not (is_menu or G.in_tutorial_mode()): 
		player.coins.get_paid(starting_coins)
	
	if is_menu:
		feedback.create_for_node(player, "Welcome!")
		GAudio.play_dynamic_sound(player, "player_logged_in")
		particles.create_at_pos(start_pos, "general_powerup", { 'subtype': 'welcome' })

func get_spread_out_position(room):
	var start_pos = room.rect.get_real_shrunk_pos()
	var max_dist = room.rect.get_real_shrunk_size()
	
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

# TO DO (Optional): if you only have one body, this SLICES that body instead?
func remove_furthest_body_of(p_num : int):
	var body_list = bodies_per_player[p_num]
	if body_list.size() <= 1: return
	
	# NOTE: deleting will also remove it from the bodies_per_player array
	# so no pop_front() or something needed by us here
	body_list[0].status.delete(false)

func remove_all_non_leading_bodies_of(p_num : int):
	var num_bodies = bodies_per_player[p_num].size()
	if num_bodies <= 1: return false
	
	while num_bodies > 1:
		remove_furthest_body_of(p_num)
		num_bodies -= 1
	
	return true

func is_furthest_body(body):
	var body_list = bodies_per_player[body.status.player_num]
	if body_list.size() <= 0: return false
	
	return body_list[0] == body

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
		
		if key in GDict.possible_starting_shapes:
			available_starting_shapes.append(key)
	
	available_shapes.shuffle()
	available_starting_shapes.shuffle()

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

func get_all_bodies_of(player_num : int):
	return bodies_per_player[player_num] + []

func _on_OrderTimer_timeout():
	sort_player_bodies()

func body_sort(a,b):
	return a.score < b.score

# On a fixed interval (somewhere around 1 second)
# It sorts all player bodies => the one with the LOWEST score is the FURTHEST, and is placed at the FRONT
# (Why? So we have extremely easy access later to bodies and their order)
func sort_player_bodies():
	for i in range(bodies_per_player.size()):
		var l = bodies_per_player[i]
		var arr = []
		
		# first build an array with both body + score
		for a in range(l.size()):
			var body = l[a]
			var my_index = body.room_tracker.get_cur_room().route.index
			var my_dist = body.room_tracker.get_dist_in_room()
			
			# my_dist is in _real pixels_
			# so we multiple the room index by some big number that will always be greater, to ensure someone in a next room always has a higher score
			var score = my_index * 1000 + my_dist
			
			var obj = {
				'body': l[a],
				'score': score
			}
			arr.append(obj)
		
		# sort it
		arr.sort_custom(self, "body_sort")

		# then put it back into place (only keeping the bodies)
		bodies_per_player[i] = []
		for a in arr:
			bodies_per_player[i].append(a.body)
