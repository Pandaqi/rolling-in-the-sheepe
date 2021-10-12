extends Node2D

var player_scene = preload("res://scenes/body.tscn")

onready var map = get_node("/root/Main/Map")

var num_players : int = 0
var player_colors = []
var player_shapes = []

# Links shape to spritesheet, but can ALSO contain unique info about the shape in the future (such as shapes that need to be lighter/heavier or cling more strongly)
var shape_list = {
	'circle': { 'frame': 0 },
	'square': { 'frame': 1 },
	'triangle': { 'frame': 2 },
	'pentagon': { 'frame': 3 },
	'hexagon': { 'frame': 4 },
	'parallellogram': { 'frame': 5 },
	'l-shape': { 'frame': 6 },
	'starpenta': { 'frame': 7 },
	'starhexa': { 'frame': 8 },
	'trapezium': { 'frame': 9 },
	'crown': { 'frame': 10 },
	'cross': { 'frame': 11 },
	'heart': { 'frame': 12 },
	'drop': { 'frame': 13 },
	'arrow': { 'frame': 14 },
	'diamond': { 'frame': 15 },
	'crescent': { 'frame': 16 },
	'trefoil': { 'frame': 17 },
	'quatrefoil': { 'frame': 18 }
}

var predefined_shapes = {}
var available_shapes = []

func activate():
	load_colors()
	load_predefined_shapes()
	
	if GlobalInput.get_player_count() <= 0:
		GlobalInput.create_debugging_players()
	
	num_players = GlobalInput.get_player_count()
	
	create_players()

func create_players():
	player_shapes = []
	player_shapes.resize(num_players)
	
	for i in range(num_players):
		create_player(i)

func get_player_shape_frame(player_num : int):
	var shape_name = player_shapes[player_num]
	return shape_list[shape_name].frame

func create_player(player_num : int):
	var player = player_scene.instance()
	
	var rand_shape = available_shapes.pop_front()
	player_shapes[player_num] = rand_shape
	player.get_node("Shaper").create_from_shape(shape_list[rand_shape].points)
	
	player.set_position(map.place_inside_room(map.cur_path[0]))
	map.add_child(player)
	
	player.get_node("Status").set_shape_name(rand_shape)
	player.get_node("Status").set_player_num(player_num)

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
		var val = Array(child.polygon)
		
		shape_list[key].points = val
		available_shapes.append(key)
	
	available_shapes.shuffle()
