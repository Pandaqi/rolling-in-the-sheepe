extends Node2D

var player_scene = preload("res://scenes/body.tscn")

onready var map = get_node("/root/Main/Map")

var player_colors = []

var predefined_shapes = {}
var available_shapes = []

func activate():
	load_colors()
	load_predefined_shapes()
	
	if GlobalInput.get_player_count() <= 0:
		GlobalInput.create_debugging_players()
	
	create_players()

func create_players():
	for i in range(GlobalInput.get_player_count()):
		create_player(i)

func create_player(player_num : int):
	var player = player_scene.instance()
	
	var rand_shape = available_shapes.pop_front()
	
	player.get_node("Shaper").create_from_shape(predefined_shapes[rand_shape])
	player.get_node("Status").set_player_num(self, player_num)
	
	player.set_position(map.place_inside_room(map.cur_path[0]))
	map.call_deferred("add_child", player)

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
		
		var key = child.name
		var val = Array(child.polygon)
		
		predefined_shapes[key] = val
		available_shapes.append(key)
	
	available_shapes.shuffle()
