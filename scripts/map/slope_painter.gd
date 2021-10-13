extends Node2D

# list of tiles (in autotile) that represent a SLOPE and not a FILLED BLOCK
var allowed_slopes = [Vector2(0,0), Vector2(1,0), Vector2(3,0), Vector2(8,0), Vector2(11,0), Vector2(0,2), Vector2(1,2), Vector2(3,2), Vector2(1,3), Vector2(3,3), Vector2(8,3), Vector2(11,3)]
var allowed_slope_indices = []

onready var map = get_node("/root/Main/Map")
onready var tilemap = get_node("/root/Main/Map/TileMap")

func _ready():
	for slope in allowed_slopes:
		allowed_slope_indices.append(slope.x + 12*slope.y)

# TO DO: Shouldn't these be functions on the RECTANGLES themselves? Or at least partly?
func should_be_slope(pos):
	# an empty cell ...
	if tilemap.get_cellv(pos) != -1: return false

	# a cell with precisely two neighbours ...
	var nbs = get_neighbor_tiles(pos, { 'filled': true })
	if nbs.size() != 2: return false
	
	# who are at an angle ( = NOT opposite each other) ...
	var epsilon = 0.05
	if (nbs[0] - pos).dot(nbs[1] - pos) < -(1 - epsilon): return false
	
	# slope!
	return true

func check_for_slopes(r):
	var slopes_to_create = []
	
	# plan the creation of new slopes
	for x in range(r.size.x):
		for y in range(r.size.y):
			var pos = r.pos + Vector2(x,y)
			if not should_be_slope(pos): continue
			
			slopes_to_create.append(pos)
	
	for pos in slopes_to_create:
		#if randf() <= 0.5: continue
		map.change_cell(pos, 0)

	map.update_bitmask(r.pos, r.size)

	var something_changed = false
	for pos in slopes_to_create:
		var tile_coord = tilemap.get_cell_autotile_coord(pos.x, pos.y)
		var tile_index = tile_coord.x + 12*tile_coord.y
		
		var good_slope = (tile_index in allowed_slope_indices)
		
		if not good_slope:
			map.change_cell(pos, -1)
			something_changed = true
	
	if something_changed:
		map.update_bitmask(r.pos, r.size)

func get_neighbor_tiles(pos, params):
	var nbs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	var res = []
	for nb in nbs:
		var new_pos = pos + nb
		var tile_data = tilemap.get_cellv(new_pos)
		
		if params.has('id'):
			if tile_data != params.id: continue
		
		if params.has('filled'):
			if tile_data < 0: continue
		
		res.append(new_pos)
	
	return res
