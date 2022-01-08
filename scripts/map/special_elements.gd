extends Node2D

const SLOPE_OFFSET : float = 1.0 - 1.0/sqrt(2.0)

onready var map = get_parent()

var item_scene = preload("res://scenes/special_element.tscn")
var available_item_types

func _ready():
	available_item_types = GDict.item_types.keys()
	
	for i in range(available_item_types.size()-1,-1,-1):
		var key = available_item_types[i]
		if GDict.item_types[key].has("unpickable"):
			available_item_types.remove(i)

func add_special_items_to_room(room, forced : bool = false):
	if not room: return
	if not room.items.can_have_special_items and (not forced): return
	
	# backtracking might cause a room to be evaluated a number of times; this ensures elements are only placed the first time
	if room.items.has_special_items(): return
	
	var num_items = 1 + randi() % 3
	
	for i in range(num_items):
		room.items.add_special_item()

func get_random_type(room):
	var tp = map.dynamic_tutorial.get_random('item', room)
	if not tp: return null
	
	var data = GDict.item_types[tp]
	if data.has('max'):
		if room.items.count_of_type(tp) >= data.max:
			return null
	
	return tp

func type_is_immediate(tp):
	return GDict.item_types[tp].has('immediate')

func type_is_toggle(tp):
	return GDict.item_types[tp].has('toggle')

func delete_on_activation(obj):
	if not GDict.item_types[obj.type].has('delete'): return
	
	var my_room = map.get_cell_from_node(obj).room
	if not my_room: return # TO DO: This should actually never happen, but it's not so bad if it triggers from time to time
	
	my_room.items.erase_special_item(obj)

func place(room, params):
	var type = get_random_type(room)
	if params.has('type'): type = params.type
	if not type: return null
	
	# determine location
	# NOTE: "tile" means we KNOW it's a filled tile in the tilemap
	var grid_pos = room.items.get_free_tile_inside(params)
	if not grid_pos: return null
	
	var item = item_scene.instance()
	var res = position_item_based_on_cell(item, grid_pos)
	if not res:
		item.queue_free()
		return null
	
	# keep reference to room that created us
	item.my_room = room
	
	# finally, add references
	map.get_cell(grid_pos).special = item
	add_child(item)
	item.set_type(type)
	
	map.dynamic_tutorial.on_usage_of('item', type)
	
	return item

func erase(obj):
	var grid_pos = map.get_grid_pos(obj.get_global_position())

	if not map.get_cell(grid_pos).special: return
	
	obj.queue_free()
	map.get_cell(grid_pos).special = null

func position_item_based_on_cell(item, grid_pos) -> bool:
	# if the cell underneath the item vanished completely, make the item vanish as well
	if map.tilemap.get_cellv(grid_pos) < 0:
		item.my_room.items.erase_special_item(item, true) # @param "hard erase"
		return false
	
	# determine rotation (based on OPEN neighbors OR slope dir) => if none possible, abort
	var nbs = map.get_neighbor_tiles(grid_pos, { 'empty': true, 'return_with_dir': true })
	if nbs.size() <= 0: return false
	
	nbs.shuffle()
	
	var real_rot = 0
	var real_pos = map.get_real_pos(grid_pos+Vector2(0.5, 0.5))
	var slope_dir = map.slope_painter.get_slope_dir(grid_pos)
	
	if not slope_dir:
		real_rot = nbs[0].dir * 0.5 * PI # just rotate to orthogonal direction
	else:
		real_rot = slope_dir.angle() # rotate according to given angle
		real_pos -= slope_dir*SLOPE_OFFSET*map.TILE_SIZE # offset to match slope position

	item.set_position(real_pos)
	item.set_rotation(real_rot)
	return true
