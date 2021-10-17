extends Node

const SLOPE_OFFSET : float = 1.0 - 1.0/sqrt(2.0)

onready var map = get_parent()

var item_scene = preload("res://scenes/special_element.tscn")
var available_item_types

func _ready():
	available_item_types = GlobalDict.item_types.keys()
	
	for i in range(available_item_types.size()-1,-1,-1):
		var key = available_item_types[i]
		if GlobalDict.item_types[key].has("unpickable"):
			available_item_types.remove(i)

func add_special_items_to_room(room):
	if not room: return
	if not room.can_have_special_items: return
	
	# if we already have items, remove all of them
	# because our configuration might have changed, so they might be invalid/floating in mid-air, so just clean it up
	if room.has_special_items(): room.clear_special_items()
	
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

func place(rect, params):
	var type = get_random_type()
	if params.has('type'): type = params.type
	if not type: return null
	
	# determine location
	# NOTE: "tile" means we KNOW it's a filled tile in the tilemap
	var grid_pos = rect.get_free_tile_inside()
	if not grid_pos: return null
	
	# determine rotation (based on neighbors OR slope dir) => if none possible, abort
	var nbs = map.get_neighbor_tiles(grid_pos, { 'empty': true, 'return_with_dir': true })
	if nbs.size() <= 0: return null
	
	nbs.shuffle()
	
	var real_rot = 0
	var real_pos = map.get_real_pos(grid_pos+Vector2(0.5, 0.5))
	var slope_dir = map.slope_painter.get_slope_dir(grid_pos)
	
	if not slope_dir:
		real_rot = nbs[0].dir * 0.5 * PI # just rotate to orthogonal direction
	else:
		real_rot = slope_dir.angle() # rotate according to given angle
		real_pos -= slope_dir*SLOPE_OFFSET*map.TILE_SIZE # offset to match slope position

	# create the actual item
	var item = item_scene.instance()
	item.set_position(real_pos)
	item.set_rotation(real_rot)
	
	# keep reference to room that created us
	item.my_room = rect
	
	# finally, add references
	map.get_cell(grid_pos).special = item
	add_child(item)
	item.set_type(type)
	
	return item

func erase(obj):
	var grid_pos = map.get_grid_pos(obj.get_global_position())

	if not map.get_cell(grid_pos).special: return
	
	obj.queue_free()
	map.get_cell(grid_pos).special = null
