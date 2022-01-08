extends Node

onready var body = get_parent()

var cur_room = null

func _module_ready():
	check_current_room()

func _physics_process(_dt):
	check_current_room()

func on_room_removed():
	cur_room = null

func get_room_after_forced_update():
	check_current_room()
	return cur_room

func figure_out_current_room():
	var cell = body.map.get_cell_from_node(body)
	
	var in_new = false
	if cell.room and cell.room.rect.real_pos_is_inside_shrunk(body.global_position):
		in_new = true
	
	var in_old = false
	if cell.old_room and cell.old_room.rect.real_pos_is_inside_shrunk(body.global_position):
		in_old = true
	
	if in_new: return cell.room
	if in_old: return cell.old_room
	return cell.room
	
	#body.map.route_generator.get_cur_room(body)
	

func check_current_room():
	var new_room = figure_out_current_room()
	if not new_room: return
	
	if new_room != cur_room:
		if cur_room: cur_room.entities.remove_player(body)
		new_room.entities.add_player(body)
	
	cur_room = new_room

func get_cur_room():
	if not cur_room or not is_instance_valid(cur_room): return body.map.route_generator.cur_path[0]
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
