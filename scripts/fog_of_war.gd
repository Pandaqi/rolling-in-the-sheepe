extends CanvasLayer

onready var camera = get_node("/root/Main/Camera2D")
onready var map = get_node("/root/Main/Map")

var mat
onready var look_ahead = $LookAhead

func _ready():
	mat = $ColorRect.material
	
	remove_child(look_ahead)
	map.add_child(look_ahead)

func _physics_process(dt):
	var players = get_tree().get_nodes_in_group("Players")
	var num_players = players.size()
	var max_lightbulbs = 20
	
	var screen_size = get_viewport().size
	mat.set_shader_param("vp_size", screen_size)
	
	var sight_radius = 200
	sight_radius /= camera.zoom.x
	mat.set_shader_param("sight_radius", sight_radius)
	
	for i in range(max_lightbulbs):
		var screen_pos = Vector2(-INF, -INF)
		if i < num_players:
			screen_pos = players[i].get_global_transform_with_canvas().origin
		elif i == num_players:
			look_ahead.set_position( lerp(look_ahead.get_position(), map.get_pos_just_ahead(), 0.1) )
			screen_pos = look_ahead.get_global_transform_with_canvas().origin
	
		mat.set_shader_param("p" + str(i), screen_pos)