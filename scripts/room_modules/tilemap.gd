extends Node

var terrain : String = ""
onready var map = get_node("/root/Main/Map")
onready var rect = get_node("../Rect")
onready var parent = get_parent()

func delete():
	fill_tiles()
	map.terrain.erase(parent)
	map.remove_cells_from_room(parent)
	
	# NOTE: I add half size here because the "paint circles" of course will EXTEND slightly beyond the room borders, as they are circles
	var mask_data = rect.get_mask_data()
	map.mask_painter.clear_rectangle(mask_data.pos, mask_data.size)

func erase_tiles():
	change_tiles_to(-1)

func fill_tiles():
	change_tiles_to(0)

func change_tiles_to(tile_id : int = -1):
	var shrunk = rect.get_shrunk()
	for x in range(shrunk.size.x):
		for y in range(shrunk.size.y):
			var temp_pos = shrunk.pos + Vector2(x,y)
			if map.out_of_bounds(temp_pos): continue
			map.change_cell(temp_pos, tile_id)
	
	map.update_bitmask_from_room(parent)

func update_map_to_new_rect():
	map.set_all_cells_to_room(parent)
	erase_tiles()
