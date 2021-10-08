extends Camera2D

const MIN_ZOOM : float = 0.25
const MAX_ZOOM : float = 4.0

const ZOOM_MARGIN : Vector2 = Vector2(250.0, 150.0)

var players
onready var generator = get_parent()

func _physics_process(dt):
	players = get_tree().get_nodes_in_group("Players")
	
	focus_on_average_player_pos(dt)
	zoom_to_show_all_players(dt)

func focus_on_average_player_pos(dt):
	var avg_pos = Vector2.ZERO
	var num_data_points = players.size()
	for p in players:
		avg_pos += p.get_global_position()
	
	avg_pos += generator.get_pos_just_ahead()
	num_data_points += 1
	
	avg_pos /= float(num_data_points)
	
	position = lerp(position, avg_pos, 5*dt)

func zoom_to_show_all_players(dt):
	var vp = get_viewport().size
	var cam_pos = get_position()
	
	var player_bounds = Vector2(-INF, -INF)
	for p in players:
		var pos = p.get_global_position()
		var x_dist = abs(pos.x - cam_pos.x)
		var y_dist = abs(pos.y - cam_pos.y)
		
		player_bounds.x = max(x_dist, player_bounds.x)
		player_bounds.y = max(y_dist, player_bounds.y)
	
	var wanted_vp = 2*player_bounds
	wanted_vp += ZOOM_MARGIN
	
	var x_zoom = wanted_vp.x / vp.x
	var y_zoom = wanted_vp.y / vp.y
	
	var zoom_val = max(x_zoom, y_zoom)
	var final_zoom = Vector2(1,1)*clamp(zoom_val, MIN_ZOOM, MAX_ZOOM)
	
	zoom = lerp(zoom, final_zoom, 5*dt)
