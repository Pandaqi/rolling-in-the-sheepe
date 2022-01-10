extends Node

const MIN_DIST_BETWEEN_TUTORIALS : int = 5

var cur_tut : int = -1
var last_tut_room = null
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
#	{
#		"key": "bigger_is_faster",
#		"frame": 18
#	},
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
		"frame": 55,
		"special": "place_spikes"
	},
	{
		"key": "coin_lock",
		"frame": 56,
		"special": "allow_placing_locks"
	},
	{
		"key": "wolf_takes_coins",
		"frame": 57
	}
]

onready var map = get_node("/root/Main/Map")

var can_place_locks : bool = false
var wolf_active : bool = false
var tiles_inside_allowed : bool = false # TO DO
var simple_route_generation : bool = true

var solo_mode : bool = false

# tutorials that are useless in solo mode
var non_solo_tutorials = ["last_player_is_wolf", "wolf_takes_coins", "unfinished_body_penalty"]

func _ready():
	solo_mode = (GInput.get_player_count() == 1)
	
	# in solo mode, some concepts don't exist (or aren't that important)
	# so remove those tutorials
	# then add a few that are slightly _different_
	if solo_mode:
		for i in range(tuts.size()-1,-1,-1):
			var obj = tuts[i]
			if obj.key in non_solo_tutorials:
				tuts.remove(i)
		
		# new objective (finish before you're caught)
		tuts[0].frame = 79
		
		# and add the "shape destroyed penalty" rule
		tuts.append({
			"key": "shape_destroy_penalty",
			"frame": 80,
			"special": "place_spikes"
		})

func on_new_room_created(room):
	if last_tut_room and is_instance_valid(last_tut_room):
		var last_tut_index = last_tut_room.route.index
		var too_soon = abs(room.route.index - last_tut_index) < MIN_DIST_BETWEEN_TUTORIALS
		if too_soon: return
	
	if not room.rect.big_enough_for_tutorial(): return
	
	load_next_tutorial(room)

func load_next_tutorial(room):
	cur_tut += 1
	if cur_tut >= tuts.size(): return
	
	var params = tuts[cur_tut]
	map.dynamic_tutorial.place_tutorial_custom(room, params)
	last_tut_room = room
	
	# check for any special things to turn on/off after this
	if params.has('special'):
		var s = params.special
		if s == "activate_wolf_rule": 
			wolf_active = true
		elif s == "allow_placing_locks": 
			can_place_locks = true
			map.dynamic_tutorial.force_allow("lock", "coin_lock")
		elif s == "remove_simple_generation": 
			simple_route_generation = false
		elif s == "allow_tiles_inside": 
			tiles_inside_allowed = true
		elif s == "place_spikes": 
			map.dynamic_tutorial.force_allow("item", "spikes")
			map.special_elements.add_special_items_to_room(map.route_generator.get_furthest_room(), true) #@param "forced" = true

func is_finished() -> bool:
	return cur_tut >= tuts.size()
