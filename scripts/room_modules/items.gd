extends Node

var can_have_special_items : bool = false
var tiles_inside = []
var special_elements = []

onready var parent = get_parent()
onready var rect = get_node("../Rect")
onready var map = get_node("/root/Main/Map")

func delete():
	clear_special_items()

func allow():
	can_have_special_items = true

func has_special_items():
	return special_elements.size() > 0

func determine_tiles_inside():
	tiles_inside = []
	
	var size = rect.size
	var pos = rect.pos
	for x in range(size.x):
		for y in range(size.y):
			var temp_pos = pos + Vector2(x,y)
			if map.tilemap.get_cellv(temp_pos) == -1: continue
			if map.out_of_bounds(temp_pos): continue
			if map.get_cell(temp_pos).room != parent: continue
			
			tiles_inside.append(temp_pos)

func get_free_tile_inside(params = {}):
	tiles_inside.shuffle()
	for tile in tiles_inside:
		if params.use_shrunk and rect.inside_growth_area_global(tile): continue
		if map.get_cell(tile).special: continue
		
		return tile

func add_special_item(params = {}):
	# TO DO: find actual good requirements for this
	var fit_for_special_item = (rect.get_area() >= 9)
	if not params.ignore_size and not fit_for_special_item: return null
	
	var elem = map.special_elements.place(parent, params)
	if not elem: return null
	
	special_elements.append(elem)
	
	return elem

func erase_special_item(item):
	special_elements.erase(item)
	map.special_elements.erase(item)

func clear_special_items():
	for item in special_elements:
		# TO DO/DEBUGGING => shouldn't be necessary I think, so something else is going wrong
		if not item or not is_instance_valid(item): continue
		map.special_elements.erase(item)
	
	special_elements = []
