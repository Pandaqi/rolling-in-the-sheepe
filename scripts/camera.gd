extends Camera2D

const MIN_ZOOM : float = 0.75
const MAX_ZOOM : float = 4.0

const ZOOM_MARGIN : Vector2 = Vector2(50.0, 50.0)

var debug_zoom_out : bool = false

var players
onready var map = get_node("/root/Main/Map")
onready var route_generator = get_node("/root/Main/Map/RouteGenerator")

# TO DO: Test if this even works AND if it's a good idea (focusing on the look ahead this much)
var look_ahead : bool = true

func set_correct_limits(dims):
	limit_left = dims.x
	limit_right = dims.x + dims.width
	
	limit_top = dims.y
	limit_bottom = dims.y + dims.height

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
	
	var coming_pos = route_generator.get_pos_just_ahead()
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
	var pos_ahead = route_generator.get_pos_just_ahead()
	if pos_ahead and look_ahead:
		player_bounds.x = max(abs(pos_ahead.x - cam_pos.x), player_bounds.x)
		player_bounds.y = max(abs(pos_ahead.y - cam_pos.y), player_bounds.y)
	
	# NOTE: Instead of adding our margin to the wanted_vp, we subtract it from the actual vp
	# This means it's _independent_ of zoom level, because we just fill the whole screen, but _pretend_ the whole screen is a bit smaller than it actually is
	var wanted_vp = 2*player_bounds
	
	var x_zoom = wanted_vp.x / (vp.x - ZOOM_MARGIN.x)
	var y_zoom = wanted_vp.y / (vp.y - ZOOM_MARGIN.y)
	
	var zoom_val = max(x_zoom, y_zoom)
	var final_zoom = Vector2(1,1)*clamp(zoom_val, MIN_ZOOM, MAX_ZOOM)
	
	if debug_zoom_out:
		final_zoom = Vector2.ONE * 5
	
	zoom = lerp(zoom, final_zoom, 5*dt)
