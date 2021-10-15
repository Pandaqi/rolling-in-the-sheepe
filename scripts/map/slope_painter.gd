extends Node2D

# list of tiles (in autotile) that represent a SLOPE and not a FILLED BLOCK
var allowed_slopes = [Vector2(1,0), Vector2(3,0), Vector2(8,0), Vector2(11,0), Vector2(1,2), Vector2(3,2), Vector2(8,3), Vector2(11,3)]
var allowed_slope_indices = []

onready var map = get_node("/root/Main/Map")
onready var tilemap = get_node("/root/Main/Map/TileMap")

func _ready():
	for slope in allowed_slopes:
		allowed_slope_indices.append(slope.x + 12*slope.y)

func placement_allowed(pos, own_room, consider_empty_room = true):
	var nbs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	var epsilon = Vector2(1,1)*0.2
	for nb in nbs:
		var grid_pos = (pos + nb + epsilon).floor()
		
		if in_growth_area(grid_pos, own_room): 
			return false
		
		var room_here = map.get_room_at(grid_pos)
		if not room_here and not consider_empty_room: continue
		if room_here == own_room: continue
		return false
	
	return true

func in_growth_area(pos, rect):
	return (pos.x == 0 or pos.x == (rect.size.x-1)) or (pos.y == 0 or pos.y == (rect.size.y-1))

func recalculate_room(r):
	if not r: return
	
	# TO DO: This has become redundant; we already loop through the WHOLE rectangle below
	# TO DO: However, isn't it better to SAVE exactly which tiles we filled inside the rectangle? Then we have a fixed, short list (instead of going through the WHOLE rectangle)
	for pos in get_slopes(r.shrunk):
		if not placement_allowed(pos, r, false): 
			map.change_cell(pos, -1)
	
	for x in range(r.shrunk.size.x):
		for y in range(r.shrunk.size.y):
			var temp_pos = r.shrunk.pos + Vector2(x,y)
			
			if tilemap.get_cellv(temp_pos) == -1: continue
			if placement_allowed(temp_pos, r): continue
			
			map.change_cell(temp_pos, -1)
	
	map.update_bitmask(r.pos, r.size)

####
# Islands
####
func fill_room(r):
	if not r: return
	
	if r.shrunk.size.x < 3 or r.shrunk.size.y < 3: return
	
	var area = r.get_area()
	var num_islands = area
	
	for _i in range(num_islands):
		var rand_pos = r.shrunk.pos+Vector2(1,1) + (Vector2(randf(), randf()) * (r.shrunk.size-Vector2(1,1)*2)).floor()
		if not placement_allowed(rand_pos, r): continue
		
		map.change_cell(rand_pos, 0)
	
	map.update_bitmask(r.pos, r.size)

####
# Slopes
####

# NOTE: r is a SHRUNK rectangle
func get_slopes(r):
	var slopes_created = []
	
	# add slopes in all four corner
	if r.size.x > 2 and r.size.y > 2:
		slopes_created.append(r.pos + Vector2(0,0))
		slopes_created.append(r.pos + Vector2(r.size.x-1,0))
		slopes_created.append(r.pos + Vector2(r.size.x-1,r.size.y-1))
		slopes_created.append(r.pos + Vector2(0, r.size.y-1))
	
	return slopes_created

func place_slopes(r):
	for pos in get_slopes(r.shrunk):
		if not placement_allowed(pos, r, false): continue
		map.change_cell(pos, 0)
	
	map.update_bitmask(r.pos, r.size)

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

func check_slope_validity(r):
	if not r: return
	
	var slopes_created = get_slopes(r)
	var something_changed = false
	
	# now check which tiles we need to remove
	for pos in slopes_created:
		var tile_coord = tilemap.get_cell_autotile_coord(pos.x, pos.y)
		var tile_index = tile_coord.x + 12*tile_coord.y
		
		var good_slope = (tile_index in allowed_slope_indices)
		if good_slope: continue
		
		map.change_cell(pos, -1)
		something_changed = true
	
	if not something_changed: return
	
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
