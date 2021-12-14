extends Node

const MIN_ROOMS_BETWEEN_TUTORIALS = 3
const MIN_ROOMS_BEFORE_TUTORIALS_START : int = 2

const NUM_TERRAIN_BOUNDS = { 'min': 2, 'max': 5 }
const NUM_LOCK_BOUNDS = { 'min': 2, 'max': 5 }
const NUM_ITEM_BOUNDS = { 'min': 1, 'max': 3 }

const MIN_COIN_THINGS = 3
const MIN_GLUE_THINGS = 1

onready var map = get_parent()

var tutorial_scene = preload("res://scenes/dynamic_tutorial.tscn")

var things_taught = {
	'terrain': [],
	'lock': [],
	'item': []
}

var things_to_teach = {
	'terrain': [],
	'lock': [],
	'item': []
}

var last_tutorial_index : int = -MIN_ROOMS_BETWEEN_TUTORIALS + MIN_ROOMS_BEFORE_TUTORIALS_START
var thing_planned = null

var first_thing : bool = true

func determine_included_types():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var all_terrains = GlobalDict.terrain_types.keys()
	all_terrains.shuffle()
	
	for i in range(all_terrains.size()-1, -1, -1):
		var key = all_terrains[i]
		if GlobalDict.terrain_types[key].has('unpickable'): 
			all_terrains.remove(i)
			continue
			
		if terrain_is_lock(key): 
			all_terrains.remove(i)
			continue
	
	var num_terrains = rng.randi_range(NUM_TERRAIN_BOUNDS.min, NUM_TERRAIN_BOUNDS.max)

	var all_locks = GlobalDict.lock_types.keys()
	all_locks.shuffle()
	var num_locks = rng.randi_range(NUM_LOCK_BOUNDS.min, NUM_LOCK_BOUNDS.max)

	var all_items = GlobalDict.item_types.keys()
	all_items.shuffle()
	var num_items = rng.randi_range(NUM_ITEM_BOUNDS.min, NUM_ITEM_BOUNDS.max)
	
	for i in range(all_items.size()-1,-1,-1):
		var key = all_items[i]
		if GlobalDict.item_types[key].has('unpickable'):
			all_items.remove(i)
	
	things_to_teach = {
		'terrain': all_terrains.slice(0, num_terrains),
		'lock': all_locks.slice(0, num_locks),
		'item': all_items.slice(0, num_items)
	}
	
	# UPGRADE: ensure at least several coin related things, so coins are not useless
	var c_num = count_things_of_type("coin_related")
	while c_num < MIN_COIN_THINGS:
		add_something_of_type("coin_related")
		c_num += 1
	
	# UPGRADE: ensure at least several things to glue your bodies back together, otherwise it's too hard
	var g_num = count_things_of_type("glue_related")
	while g_num < MIN_GLUE_THINGS:
		add_something_of_type("glue_related")
		g_num += 1
	
	print("DYNAMIC TUTORIAL")
	print(things_to_teach)

func count_things_of_type(tp : String):
	var sum = 0
	for key in things_to_teach:
		var list_key = key + "_types"
		for thing in things_to_teach[key]:
			if GlobalDict[list_key][thing].has(tp):
				sum += 1
	return sum

func add_something_of_type(tp : String):
	var all_available = []
	for key in things_to_teach:
		var list_key = key + "_types"
		for thing in GlobalDict[list_key]:
			if not GlobalDict[list_key][thing].has(tp): continue
			if (thing in things_to_teach[key]): continue
			
			all_available.append({ 'key': key, 'thing': thing })
	
	var rand = all_available[randi() % all_available.size()]
	things_to_teach[rand.key].append(rand.thing)

func terrain_is_lock(key):
	return GlobalDict.terrain_types[key].category == 'lock'

func is_thing_already_used(kind : String, type : String):
	return type in things_taught[kind]

func can_teach_something_new():
	print("CAN TEACH SOMETHING NEW?")
	
	if Global.in_tutorial_mode(): return false
	
	var too_soon = abs(map.route_generator.get_new_room_index() - last_tutorial_index) < MIN_ROOMS_BETWEEN_TUTORIALS
	if too_soon: return false
	
	var still_busy = has_something_planned()
	if still_busy: return false
	
	return true

func has_something_planned():
	return thing_planned != null

func get_kind_planned():
	return thing_planned

func on_usage_of(kind : String, type : String):
	if not things_taught.has(kind): return
	if not things_to_teach.has(kind): return
	
	var not_in_this_game = not (type in things_to_teach[kind])
	var already_used = (type in things_taught[kind])
	if already_used or not_in_this_game: return
	
	things_taught[kind].append(type)
	
	things_to_teach[kind].erase(type)
	if things_to_teach[kind].size() <= 0:
		things_to_teach.erase(kind)
	
	if thing_planned.kind == kind and thing_planned.type == type:
		thing_planned = null
	
	print("USAGE OF")
	print(kind)
	print(type)

func needs_tutorial():
	return has_something_planned() and not thing_planned.tutorial_placed

func get_random(kind : String, room = null):
	if has_something_planned():
		if thing_planned.kind == kind and thing_planned.tutorial_placed:
			if not room or room.rect.big_enough_for_tutorial():
				return thing_planned.type
	
	var types_list = things_taught[kind]
	if types_list.size() <= 0: return null
	
	var rand_type = types_list[randi() % types_list.size()]
	return rand_type

func has_random(kind : String, room = null):
	return get_random(kind, room) != null

func plan_random_placement(wanted_kind : String = 'any'):
	var kinds_left = things_to_teach.keys()
	if kinds_left.size() <= 0: return false
	
	var rand_kind = kinds_left[randi() % kinds_left.size()]
	if wanted_kind != 'any': rand_kind = wanted_kind
	
	if first_thing: 
		rand_kind = 'terrain'
		first_thing = false
	
	var types_list = things_to_teach[rand_kind]
	var rand_type = types_list[randi() % types_list.size()]
	
	thing_planned = { 'kind': rand_kind, 'type': rand_type, 'tutorial_placed': false }
	
	# DEBUGGING
	#thing_planned = { 'kind': 'terrain', 'type': 'body_cleanup', 'tutorial_placed': false }
	
	# if no dynamic tutorials enabled (globally), skip the whole tutorial part
	# TO DO: might also want to skip this whole system, so no need to gradually introduce things
	if not GlobalDict.cfg.dynamic_tutorials:
		thing_planned.tutorial_placed = true
	
	print("THING PLANNED")
	print(thing_planned)
	
	return true

func place_tutorial_custom(room, params):
	var tut = tutorial_scene.instance()
	tut.set_position(room.rect.get_center())
	tut.get_node("Sprite").set_frame(params.frame)
	map.add_child(tut)

func place_tutorial(room):
	var self_placement = room.tilemap.terrain == "teleporter"
	if not has_something_planned() and not self_placement: return
	
	var tut = tutorial_scene.instance()
	tut.set_position(room.rect.get_center())
	
	var frame = 0
	if self_placement: frame = 38
	else: frame = get_planned_frame()
	
	tut.get_node("Sprite").set_frame(frame)
	map.add_child(tut)
	
	if self_placement: return
	
	thing_planned.tutorial_placed = true
	last_tutorial_index = map.route_generator.get_new_room_index()
	
	print("PLACED TUTORIAL FOR")
	print(thing_planned)

func get_planned_frame():
	var key = thing_planned.kind + "_types"
	var list = GlobalDict[key]
	
	# DEBUGGING => for as long as I don't have all tutorials yet
	if not list[thing_planned.type].has('tut'): return 0
	
	return list[thing_planned.type].tut
