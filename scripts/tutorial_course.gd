extends Node

const MIN_DIST_BETWEEN_TUTORIALS : int = 5

var cur_tut : int = -1
var last_tut_index : int = -INF
var tuts = [
	{
		"key": "objective",
		"frame": 17
	},
	{
		"key": "jump",
		"frame": 16,
		"special": "remove_simple_generation"
	},
	{
		"key": "rolling_makes_round",
		"frame": 19
	},
	{
		"key": "bigger_is_faster",
		"frame": 18
	},
	{
		"key": "float",
		"frame": 24,
		"special": "allow_tiles_inside"
	},
	{
		"key": "last_player_is_wolf",
		"frame": 20,
		"special": "activate_wolf_rule"
	},
	{
		"key": "unfinished_body_penalty",
		"frame": 0 # TO DO
	},
	{
		"key": "coin_lock",
		"frame": 0, # TO DO
		"special": "allow_placing_locks"
	},
	{
		"key": "wolf_takes_coins",
		"frame": 0 # TO DO
	}
]

onready var map = get_node("/root/Main/Map")

var can_place_locks : bool = false
var wolf_active : bool = false
var tiles_inside_allowed : bool = false # TO DO
var simple_route_generation : bool = true

func on_new_room_created(room):
	var too_soon = abs(room.route.index - last_tut_index) < MIN_DIST_BETWEEN_TUTORIALS
	if too_soon: return
	
	if not room.rect.big_enough_for_tutorial(): return
	
	load_next_tutorial(room)

func load_next_tutorial(room):
	cur_tut += 1
	if cur_tut >= tuts.size(): return
	
	var params = tuts[cur_tut]
	map.dynamic_tutorial.place_tutorial_custom(room, params)
	last_tut_index = room.route.index
	
	# check for any special things to turn on/off after this
	if params.has('special'):
		var s = params.special
		if s == "activate_wolf_rule": wolf_active = true
		elif s == "allow_placing_locks": can_place_locks = true
		elif s == "remove_simple_generation": simple_route_generation = false
		elif s == "allow_tiles_inside": tiles_inside_allowed = true
