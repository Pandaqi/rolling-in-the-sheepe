extends Node2D

var cur_room = null

onready var map = get_node("/root/Main/Map")
onready var route_generator = get_node("/root/Main/Map/RouteGenerator")
onready var body = get_parent()

func _ready():
	cur_room = route_generator.cur_path[0]
	cur_room.add_player(body)

func _physics_process(_dt):
	check_current_room()

func check_current_room():
	var new_room = route_generator.get_cur_room(body)
	if not new_room: return
	
	if new_room != cur_room:
		cur_room.remove_player(body)
		new_room.add_player(body)
	
	cur_room = new_room

func get_cur_room():
	return cur_room
