extends Node

var lock_module
var lock_planned : bool = false

var gates = []

onready var map = get_node("/root/Main/Map")
onready var route_generator = get_node("/root/Main/Map/RouteGenerator")
onready var outline = get_node("../Outline")
onready var parent = get_parent()

func on_body_enter(p):
	if not has_lock(): return
	lock_module.on_body_enter(p)

func on_body_exit(p):
	if not has_lock(): return
	lock_module.on_body_exit(p)

func plan():
	lock_planned = true

func has_lock():
	return (lock_module != null)

func add_lock():
	var rand_type = map.locker.get_random_type()
	var data = GlobalDict.lock_types[rand_type]
	
	var related_edge = "regular"
	if data.has("edge_type"): related_edge = data.edge_type
	outline.create_border_around_us({ 'type': related_edge })
	
	var related_terrain = data.terrain
	map.terrain.paint(parent, related_terrain)
	
	var scene = load("res://scenes/locks/" + rand_type + ".tscn").instance()
	scene.my_room = parent
	scene.coin_related = data.has("coin")
	
	lock_module = scene
	map.add_child(scene)
	
	print("Should add lock now")

func remove_lock():
	outline.remove_border_around_us()
	lock_module = null
	
	print("Should remove lock now")

# TO DO: Merge with the general "add_lock" function?
func add_teleporter():
	remove_lock()
	
	lock_module = load("res://scenes/locks/teleporter.tscn").instance()
	lock_module.my_room = parent
	map.add_child(lock_module)
	
	map.terrain.paint(parent, "teleporter")
	outline.create_border_around_us({ 'open_all_linked_edges': true })

func recalculate_gates():
	if not has_lock(): return
	lock_module.convert_connection_to_gate()

func check_planned_lock():
	if not lock_planned: return
	
	add_lock()
	lock_planned = false
	
	route_generator.placed_lock()

func record_button_push(pusher):
	return lock_module.record_button_push(pusher)

func delete():
	if not has_lock(): return
	lock_module.delete()
