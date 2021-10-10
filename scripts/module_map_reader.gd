extends Node2D

onready var map = get_node("/root/Main/Map")
onready var body = get_parent()

var has_finished : bool = false

func _physics_process(dt):
	if has_finished: return
	
	var cur_cell = map.get_cell_from_node(self)
	var terrain = cur_cell.terrain
	var room = map.get_room_at(cur_cell.pos) # can be null??
	
	if terrain == "finish":
		print("WE'VE FINISHED!")
		has_finished = true
		
		disable_everything()
	
	elif terrain == "teleporter":
		print("ON TELEPORTER")
		room.lock_module.register_player(body)

func disable_everything():
	body.collision_layer = 2
	body.collision_mask = 2
	
	body.modulate.a = 0.5

