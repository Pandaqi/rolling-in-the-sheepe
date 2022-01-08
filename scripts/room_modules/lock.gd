extends Node

var lock_module
var lock_planned : bool = false
var was_lock : bool = false
var lock_data = {}

var edge_type : String = "regular"

var gates = []

onready var parent = get_parent()

func on_body_enter(p):
	if not has_lock(): return
	lock_module.on_body_enter(p)

func on_body_exit(p):
	if not has_lock(): return
	lock_module.on_body_exit(p)

func plan():
	lock_planned = true

func has_lock_or_planned():
	return has_lock() or lock_planned

func has_lock_or_was_lock():
	return has_lock() or was_lock

func has_lock():
	return (lock_module != null)

# Returns whether it was a SUCCESS or a FAIL
# (if a fail, we don't definitively set it, so the algorithm will keep trying on subsequent rooms)
func add_lock(forced_type : String = "") -> bool:
	if has_lock(): return false
	
	var rand_type = parent.map.dynamic_tutorial.get_random('lock', parent)
	if forced_type != "": rand_type = forced_type
	
	var data = GDict.lock_types[rand_type]
	lock_data = data
	
	# some locks have many different (similar) variants, 
	# so we instantiate the same scene for them
	# but modify via subtypes
	var rand_sub_type = null
	if data.has('lock_group'):
		rand_type = data.lock_group
		rand_sub_type = data.sub_type
	
	var scene = load("res://scenes/locks/" + rand_type + ".tscn").instance()
	scene.link_to_room({ 'room': parent, 'coin_related': data.has("coin_related") })
	
	if rand_sub_type: scene.set_sub_type(rand_sub_type)
	
	parent.map.lock_module_layer.add_child(scene)
	
	if scene.is_invalid(): 
		scene.delete()
		return false
	
	if data.has("edge_type"): 
		edge_type = data.edge_type

	var related_terrain = data.terrain
	parent.map.terrain.paint(parent, related_terrain)
	
	lock_module = scene
	parent.map.dynamic_tutorial.on_usage_of('lock', rand_type)
	was_lock = true

	return true

func remove_lock(hard_remove : bool = false):
	if hard_remove:
		parent.outline.remove_border_around_us()
	else:
		parent.outline.turn_border_into_soft_border()
	
	lock_module = null

func add_teleporter():
	# first remove any previous lock that might have been here (a HARD remove)
	remove_lock(true)
	add_lock("teleporter")

func add_finish():
	remove_lock(true)
	add_lock("finish")

func check_planned_lock():
	if not lock_planned: return
	
	var success = add_lock()
	if not success: return 
	
	lock_planned = false
	parent.map.route_generator.placed_lock()

func record_button_push(pusher):
	return lock_module.record_button_push(pusher)

func perform_update():
	lock_module.perform_update()

func delete(hard_remove : bool = false):
	if not has_lock(): return
	lock_module.delete(hard_remove)
