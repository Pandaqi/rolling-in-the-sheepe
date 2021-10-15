extends Node2D

onready var map = get_parent()

var item_scene = preload("res://scenes/special_element.tscn")
var available_item_types

func _ready():
	available_item_types = GlobalDict.item_types.keys()

func get_random_type():
	if available_item_types.size() <= 0: return null
	return available_item_types[randi() % available_item_types.size()]

func type_is_immediate(tp):
	return GlobalDict.item_types[tp].has('immediate')

func type_is_ongoing(tp):
	return GlobalDict.item_types[tp].has('ongoing')

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
	var real_rot = nbs[0].dir * 0.5 * PI
	var real_pos = map.get_real_pos(grid_pos+Vector2(0.5, 0.5))
	
	# TO DO: if a slope, we need to angle it an extra 45 degrees
	# (based on direction of slope => also return that from the slope painter
	if map.slope_painter.tile_is_slope(grid_pos):
		pass
	
	# create the actual item
	var item = item_scene.instance()
	item.set_type(type)
	item.set_position(real_pos)
	item.set_rotation(real_rot)
	
	# finally, add references
	map.get_cell(grid_pos).special = item
	add_child(item)

func erase(obj):
	var grid_pos = map.get_grid_pos(obj.item.get_global_position())

	if not map.get_cell(grid_pos).special: return
	
	obj.item.queue_free()
	map.get_cell(grid_pos).special = null
