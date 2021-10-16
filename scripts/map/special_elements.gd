extends Node

onready var map = get_parent()

var item_scene = preload("res://scenes/special_element.tscn")
var available_item_types

func _ready():
	available_item_types = GlobalDict.item_types.keys()

func add_special_items_to_room(room):
	if not room: return
	if not room.can_have_special_items: return
	
	room.determine_tiles_inside()
	
	room.add_special_item()

func get_random_type():
	if available_item_types.size() <= 0: return null
	return available_item_types[randi() % available_item_types.size()]

func type_is_immediate(tp):
	return GlobalDict.item_types[tp].has('immediate')

func type_is_ongoing(tp):
	return GlobalDict.item_types[tp].has('ongoing')

func delete_on_activation(obj):
	if not GlobalDict.item_types[obj.type].has('delete'): return
	
	var my_room = map.get_cell_from_node(obj).room
	if not my_room: return # TO DO: This should actually never happen, but it's not so bad if it triggers from time to time
	
	my_room.erase_special_item(obj)

func place(rect):
	var type = get_random_type()
	if not type: return
	
	# determine location
	# NOTE: "tile" means we KNOW it's a filled tile in the tilemap
	var grid_pos = rect.get_free_tile_inside()
	
	# determine rotation (based on neighbors OR slope dir) => if none possible, abort
	var nbs = map.get_neighbor_tiles(grid_pos, { 'empty': true, 'return_with_dir': true })
	if nbs.size() <= 0: return
	
	nbs.shuffle()
	
	var real_rot = 0
	var real_pos = map.get_real_pos(grid_pos+Vector2(0.5, 0.5))
	var slope_dir = map.slope_painter.get_slope_dir(grid_pos)

	if not slope_dir:
		real_rot = nbs[0].dir * 0.5 * PI # just rotate to orthogonal direction
	else:
		real_rot = slope_dir.angle() # rotate according to given angle
		real_pos -= slope_dir*0.5*map.TILE_SIZE # offset to match slope position

	# create the actual item
	var item = item_scene.instance()
	item.set_type(type)
	item.set_position(real_pos)
	item.set_rotation(real_rot)
	
	# finally, add references
	map.get_cell(grid_pos).special = item
	add_child(item)

func erase(obj):
	var grid_pos = map.get_grid_pos(obj.get_global_position())

	if not map.get_cell(grid_pos).special: return
	
	obj.queue_free()
	map.get_cell(grid_pos).special = null
