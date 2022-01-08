extends Node

var can_have_special_items : bool = false
var tiles_inside = []
var special_elements = []

onready var parent = get_parent()

func delete():
	clear_special_items()

func allow():
	can_have_special_items = true

func has_special_items():
	return special_elements.size() > 0

func count():
	return special_elements.size()

func determine_tiles_inside():
	tiles_inside = []

	var map = parent.map
	for temp_pos in parent.rect.positions:
		if map.tilemap.get_cellv(temp_pos) == -1: continue
		if map.get_cell(temp_pos).room != parent: continue
		
		tiles_inside.append(temp_pos)

func get_free_tile_inside(params = {}):
	tiles_inside.shuffle()
	for tile in tiles_inside:
		if params.has('use_shrunk') and parent.rect.inside_growth_area_global(tile): continue
		if parent.map.get_cell(tile).special: continue
		if not parent.map.slope_painter.tile_can_hold_item(tile): continue
		
		return tile

func add_special_item(params = {}):
	# TO DO: find actual good requirements for this
	var fit_for_special_item = (parent.rect.get_area() >= 9)
	if not params.has('ignore_size') and not fit_for_special_item: return null
	
	var elem = parent.map.special_elements.place(parent, params)
	if not elem: return null
	
	special_elements.append(elem)
	
	return elem

func erase_special_item(item, hard_erase : bool = false):
	special_elements.erase(item)
	parent.map.special_elements.erase(item)

func clear_special_items():
	for item in special_elements:
		# TO DO/DEBUGGING => shouldn't be necessary I think, so something else is going wrong
		if not item or not is_instance_valid(item): continue
		parent.map.special_elements.erase(item)
	
	special_elements = []
