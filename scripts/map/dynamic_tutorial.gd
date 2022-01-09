extends Node

const MIN_ROOMS_BETWEEN_TUTORIALS = 3
const MIN_ROOMS_BEFORE_TUTORIALS_START : int = 2

const NUM_TERRAIN_BOUNDS = { 'min': 2, 'max': 5 }
const NUM_LOCK_BOUNDS = { 'min': 2, 'max': 4 }
const NUM_ITEM_BOUNDS = { 'min': 1, 'max': 7 }

const MIN_COIN_THINGS = 3
const MIN_GLUE_THINGS = 1

onready var map = get_parent()
onready var solo_mode = get_node("/root/Main/SoloMode")

var tutorial_scene = preload("res://scenes/dynamic_tutorial.tscn")

var things_taught : Dictionary = {
	'terrain': [],
	'lock': [],
	'item': []
}

var things_to_teach : Dictionary = {
	'terrain': [],
	'lock': [],
	'item': []
}

var probs : Dictionary = {
	'terrain': 1.0,
	'lock': 1.0,
	'item': 1.0
}

var last_placement_kinds = []
var all_allowed_things = []

var last_tutorial_index : int = -MIN_ROOMS_BETWEEN_TUTORIALS + MIN_ROOMS_BEFORE_TUTORIALS_START
var rooms_placed_since_last_tutorial : int = 0

var final_tut_room : int = -1
var thing_planned = null

var first_thing : bool = true

func _ready():
	# cache the probability of each item, saves loads of calculations down the line
	prepare_probabilities('terrain')
	prepare_probabilities('lock')
	prepare_probabilities('item')

func get_list_from_kind(kind : String):
	var ref = GDict.terrain_types
	if kind == 'lock': ref = GDict.lock_types
	elif kind == 'item': ref = GDict.item_types
	return ref

func prepare_probabilities(kind : String):
	var ref = get_list_from_kind(kind)
	for key in ref:
		var final_prob = 1
		if not ref[key].has('prob'):
			final_prob = 1
		else:
			final_prob = ref[key].prob
		
		if solo_mode.is_active() and ref[key].has("solo_prob"):
			final_prob = ref[key].solo_prob
		
		ref[key].final_prob = final_prob

func update_probabilities(kind : String):
	if not things_taught.has(kind): return
	
	var total_prob : float = 0
	var ref = get_list_from_kind(kind)
	for key in things_taught[kind]:
		total_prob += ref[key].final_prob
	
	probs[kind] = total_prob

func draw_list_weighted(kind : String, list : Array, num : int):
	list = list + []
	
	var ref = get_list_from_kind(kind)
	var total_prob = probs[kind]
	var arr = []
	while arr.size() < num:
		var running_sum : float = 0.0
		var target : float = randf()
		
		var chosen_key
		for key in list:
			running_sum += ref[key].final_prob / float(total_prob) 
			chosen_key = key
			if running_sum >= target: break
		
		arr.append(chosen_key)
		list.erase(chosen_key)
	
	return arr

func determine_included_types():
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	var all_terrains = GDict.terrain_types.keys()
	remove_unpickables(all_terrains, GDict.terrain_types)
	all_terrains.shuffle()
	
	var num_terrains = rng.randi_range(NUM_TERRAIN_BOUNDS.min, NUM_TERRAIN_BOUNDS.max)

	var all_locks = GDict.lock_types.keys()
	remove_unpickables(all_locks, GDict.lock_types)
	all_locks.shuffle()
	var num_locks = rng.randi_range(NUM_LOCK_BOUNDS.min, NUM_LOCK_BOUNDS.max)

	var all_items = GDict.item_types.keys()
	all_items.shuffle()
	remove_unpickables(all_items, GDict.item_types)
	var num_items = rng.randi_range(NUM_ITEM_BOUNDS.min, NUM_ITEM_BOUNDS.max)
	
	for i in range(all_items.size()-1,-1,-1):
		var key = all_items[i]
		if GDict.item_types[key].has('unpickable'):
			all_items.remove(i)
	
	things_to_teach = {
		'terrain': draw_list_weighted("terrain", all_terrains, num_terrains),
		'lock': draw_list_weighted("lock", all_locks, num_locks),
		'item': draw_list_weighted("item", all_items, num_items)
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
	
	# DEMO MODE: just include everything allowed in demo
	if G.is_demo():
		things_to_teach = {
			"terrain": get_all_demo_items(GDict.terrain_types),
			"lock": get_all_demo_items(GDict.lock_types),
			"item": get_all_demo_items(GDict.item_types)
		}
	
	if GDict.cfg.debug_quick_dynamic_tutorial:
		things_to_teach = {
			'lock': ['painter_lock']
		}
	
	for key in things_to_teach:
		for item in things_to_teach[key]:
			all_allowed_things.append(item)

func get_all_demo_items(arr):
	var keys = arr.keys()
	var new_arr = []
	for key in keys:
		if not arr[key].has('demo'): continue
		new_arr.append(key)
	return new_arr

func remove_unpickables(arr, ref_arr):
	for i in range(arr.size()-1, -1, -1):
		var key = arr[i]
		if ref_arr[key].has('unpickable'): 
			arr.remove(i)
			continue
		
		if solo_mode.is_active() and ref_arr.has('solo_unpickable'):
			arr.remove(i)
			continue
		
		if not solo_mode.is_active() and ref_arr.has('multi_unpickable'):
			arr.remove(i)
			continue

func count_things_of_type(tp : String):
	var sum = 0
	for key in things_to_teach:
		var list_key = key + "_types"
		for thing in things_to_teach[key]:
			if GDict[list_key][thing].has(tp):
				sum += 1
	return sum

func add_something_of_type(tp : String):
	var all_available = []
	for key in things_to_teach:
		var list_key = key + "_types"
		for thing in GDict[list_key]:
			if not GDict[list_key][thing].has(tp): continue
			if (thing in things_to_teach[key]): continue
			
			all_available.append({ 'key': key, 'thing': thing })
	
	var rand = all_available[randi() % all_available.size()]
	things_to_teach[rand.key].append(rand.thing)

func terrain_is_lock(key):
	return GDict.terrain_types[key].category == 'lock'

func is_thing_already_used(kind : String, type : String):
	return type in things_taught[kind]

func can_teach_something_new():
	if G.in_tutorial_mode(): return false
	
	var too_soon = abs(map.route_generator.get_new_room_index() - last_tutorial_index) < MIN_ROOMS_BETWEEN_TUTORIALS
	if too_soon: return false
	
	var still_busy = has_something_planned()
	if still_busy: return false
	
	return true

func has_something_planned():
	return thing_planned != null

func get_kind_planned():
	return thing_planned

func force_allow(kind : String, type : String):
	if not things_taught.has(kind): things_taught[kind] = []
	things_taught[kind].append(type)
	update_probabilities(kind)

func on_usage_of(kind : String, type : String):
	if not has_something_planned(): return
	if not type in all_allowed_things: return
	
	if things_taught.has(kind) and not (type in things_taught[kind]):
		things_taught[kind].append(type)
		update_probabilities(kind)
	
	if things_to_teach.has(kind) and (type in things_to_teach[kind]):
		things_to_teach[kind].erase(type)
	
		if things_to_teach[kind].size() <= 0:
	# warning-ignore:return_value_discarded
			things_to_teach.erase(kind)
	
	if thing_planned.kind == kind and thing_planned.type == type:
		thing_planned = null
		last_placement_kinds.append(kind)
	
	print("USAGE OF: " + kind + " || " + type)

func needs_tutorial():
	return has_something_planned() and not thing_planned.tutorial_placed

func get_random(kind : String, room = null):
	if has_something_planned():
		if thing_planned.kind == kind and thing_planned.tutorial_placed:
			if not room or room.rect.big_enough_for_tutorial():
				return thing_planned.type
	
	var types_list = things_taught[kind]
	if types_list.size() <= 0: return null

	
	var rand_type = draw_list_weighted(kind, types_list, 1)[0]
	return rand_type

func has_random(kind : String, room = null):
	return get_random(kind, room) != null

func plan_random_placement(wanted_kind : String = 'any'):
	var kinds_left = things_to_teach.keys()
	if kinds_left.size() <= 0: return false
	
	var rand_kind = kinds_left[randi() % kinds_left.size()]
	if wanted_kind != 'any': rand_kind = wanted_kind
	
	# UPGRADE: forbid two of the same type after each other, but only for locks
	if kinds_left.size() > 1 and last_placement_kinds.size() > 0:
		var last_placed_kind = last_placement_kinds[last_placement_kinds.size()-1]
		
		if last_placed_kind == "lock":
			while rand_kind == last_placed_kind:
				rand_kind = kinds_left[randi() % kinds_left.size()]
	
	if first_thing and things_to_teach.has('terrain'): 
		rand_kind = 'terrain'
		first_thing = false
	
	var types_list = things_to_teach[rand_kind]
	var rand_type = types_list[randi() % types_list.size()]
	
	# DEBUGGING => FOR TESTING NEW STUFF
	rand_kind = 'item'
	rand_type = 'magnet_beam'
	
	thing_planned = { 'kind': rand_kind, 'type': rand_type, 'tutorial_placed': false }
	
	# if no dynamic tutorials enabled (globally), skip the whole tutorial part
	# TO DO: might also want to skip this whole system, so no need to gradually introduce things
	if not GDict.cfg.show_dynamic_tutorials:
		thing_planned.tutorial_placed = true
	
	print("THING PLANNED")
	print(thing_planned)
	
	return true

func place_tutorial_custom(room, params):
	var tut = tutorial_scene.instance()
	tut.set_position(room.rect.get_real_center())
	tut.get_node("Sprite").set_frame(params.frame)
	
	map.bg_layer.add_child(tut)
	room.connect_related_item(tut)
	room.on_tutorial_placement()
	rooms_placed_since_last_tutorial = 0
	
	if is_everything_taught():
		final_tut_room = map.route_generator.get_new_room_index()

func place_tutorial(room):
	var self_placement = room.tilemap.terrain == "teleporter"
	if not has_something_planned() and not self_placement: return
	
	var tut = tutorial_scene.instance()
	tut.set_position(room.rect.get_real_center())
	
	var frame = 0
	if self_placement: frame = 38
	else: frame = get_planned_frame()
	
	tut.get_node("Sprite").set_frame(frame)
	
	room.connect_related_item(tut)
	room.on_tutorial_placement()
	rooms_placed_since_last_tutorial = 0
	map.bg_layer.add_child(tut)
	
	# when a tutorial is placed in its own room, it's quite distracting and probably obscures something
	# so scale it down, make a bit transparent
	if self_placement: 
		tut.set_scale(tut.get_scale()*0.5)
		tut.modulate.a = 0.8
		return
	
	thing_planned.tutorial_placed = true
	last_tutorial_index = map.route_generator.get_new_room_index()
	
	print("PLACED TUTORIAL FOR")
	print(thing_planned)
	
	if is_everything_taught():
		final_tut_room = map.route_generator.get_new_room_index()

func get_planned_frame():
	var key = thing_planned.kind + "_types"
	var list = GDict[key]
	if not list[thing_planned.type].has('tut'): return 0
	
	return list[thing_planned.type].tut

func is_everything_taught() -> bool:
	if G.in_tutorial_mode():
		return map.room_picker.tutorial_course.is_finished()
	else:
		return things_to_teach.keys().size() <= 0

func on_room_placed():
	rooms_placed_since_last_tutorial += 1
