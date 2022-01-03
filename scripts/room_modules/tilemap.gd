extends Node

onready var parent = get_parent()

var terrain : String = ""

func delete():
	fill_tiles()
	parent.map.terrain.erase(parent)
	parent.map.remove_cells_from_room(parent)
	
	# NOTE: I add half size here because the "paint circles" of course will EXTEND slightly beyond the room borders, as they are circles
	var mask_data = parent.rect.get_mask_data()
	parent.map.mask_painter.clear_rectangle(mask_data.pos, mask_data.size)

func is_cell_filled(pos: Vector2):
	return parent.map.tilemap.get_cellv(pos) >= 0

func erase_tiles():
	change_tiles_to(-1)

func fill_tiles():
	change_tiles_to(0)

func change_tiles_to(tile_id : int = -1):
	for temp_pos in parent.rect.shrunk_positions:
		if parent.map.out_of_bounds(temp_pos): continue
		parent.map.change_cell(temp_pos, tile_id)
	
	parent.map.update_bitmask_from_room(parent)

func update_map_to_new_rect():
	parent.map.set_all_cells_to_room(parent)
	erase_tiles()
