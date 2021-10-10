extends Camera2D

const MIN_ZOOM : float = 0.75
const MAX_ZOOM : float = 4.0

const ZOOM_MARGIN : Vector2 = Vector2(250.0, 150.0)

var players
onready var map = get_node("/root/Main/Map")

# TO DO: Test if this even works AND if it's a good idea (focusing on the look ahead this much)
var look_ahead : bool = false

func _physics_process(dt):
	players = get_tree().get_nodes_in_group("Players")
	
	focus_on_average_player_pos(dt)
	zoom_to_show_all_players(dt)

func focus_on_average_player_pos(dt):
	if players.size() <= 0: return
	
	var avg_pos : Vector2 = Vector2.ZERO
	var num_data_points : float = players.size()
	for p in players:
		avg_pos += p.get_global_position()
	
	var coming_pos = map.get_pos_just_ahead()
	if coming_pos and look_ahead:
		var coming_pos_weight = 2.0
		avg_pos += coming_pos_weight * coming_pos
		num_data_points += coming_pos_weight
	
	avg_pos /= float(num_data_points)
	
	position = lerp(position, avg_pos, 5*dt)

func zoom_to_show_all_players(dt):
	if players.size() <= 0: return
	
	var vp = get_viewport().size
	var cam_pos = get_position()
	
	# check all players
	var player_bounds = Vector2(-INF, -INF)
	for p in players:
		var pos = p.get_global_position()
		var x_dist = abs(pos.x - cam_pos.x)
		var y_dist = abs(pos.y - cam_pos.y)
		
		player_bounds.x = max(x_dist, player_bounds.x)
		player_bounds.y = max(y_dist, player_bounds.y)
	
	# check that position up ahead, to include it as well
	var pos_ahead = map.get_pos_just_ahead()
	if pos_ahead and look_ahead:
		player_bounds.x = max(abs(pos_ahead.x - cam_pos.x), player_bounds.x)
		player_bounds.y = max(abs(pos_ahead.y - cam_pos.y), player_bounds.y)
	
	var wanted_vp = 2*player_bounds
	wanted_vp += ZOOM_MARGIN
	
	var x_zoom = wanted_vp.x / vp.x
	var y_zoom = wanted_vp.y / vp.y
	
	var zoom_val = max(x_zoom, y_zoom)
	var final_zoom = Vector2(1,1)*clamp(zoom_val, MIN_ZOOM, MAX_ZOOM)
	
	zoom = lerp(zoom, final_zoom, 5*dt)
