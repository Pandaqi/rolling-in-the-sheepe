extends Node

var cur_room = null

onready var map = get_node("/root/Main/Map")
onready var route_generator = get_node("/root/Main/Map/RouteGenerator")
onready var body = get_parent()

func _ready():
	cur_room = route_generator.get_cur_room(body)
	if not cur_room: return
	cur_room.entities.add_player(body)

func _physics_process(_dt):
	check_current_room()

func get_room_after_forced_update():
	check_current_room()
	return cur_room

func check_current_room():
	var new_room = route_generator.get_cur_room(body)
	if not new_room: return
	
	if new_room != cur_room:
		if cur_room: cur_room.entities.remove_player(body)
		new_room.entities.add_player(body)
	
	cur_room = new_room

func get_cur_room():
	return cur_room

# TO DO: Probably a way to streamline this, instead of the if-statement
func get_dist_in_room():
	if not cur_room: return 0
	
	var d = cur_room.route.dir
	var diff = (body.get_global_position() - cur_room.rect.get_real_pos())
	if d == 0:
		return diff.x
	elif d == 1:
		return diff.y
	elif d == 2:
		return cur_room.rect.get_real_size().x - diff.x
	elif d == 3:
		return cur_room.rect.get_real_size().y - diff.y
