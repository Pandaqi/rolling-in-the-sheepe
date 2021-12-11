extends Node

# list of tiles (in autotile) that represent a SLOPE and not a FILLED BLOCK
var allowed_slopes = [Vector2(1,0), Vector2(3,0), Vector2(8,0), Vector2(11,0), Vector2(1,2), Vector2(3,2), Vector2(8,3), Vector2(11,3)]
var allowed_slope_dirs = [Vector2(-1,-1), Vector2(1,-1), Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1),Vector2(1,1), Vector2(-1,1), Vector2(1,1)]
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

func in_growth_area(pos, room):
	return (pos.x == 0 or pos.x == (room.rect.size.x-1)) or (pos.y == 0 or pos.y == (room.rect.size.y-1))

func recalculate_room(room):
	if not room: return
	
	# TO DO: This has become redundant; we already loop through the WHOLE rectangle below
	# TO DO: However, isn't it better to SAVE exactly which tiles we filled inside the rectangle? Then we have a fixed, short list (instead of going through the WHOLE rectangle)
	var shrunk = room.rect.get_shrunk()
	for pos in get_slopes(room):
		if not placement_allowed(pos, room, false): 
			map.change_cell(pos, -1)
	
	for x in range(shrunk.size.x):
		for y in range(shrunk.size.y):
			var temp_pos = shrunk.pos + Vector2(x,y)
			
			if tilemap.get_cellv(temp_pos) == -1: continue
			if placement_allowed(temp_pos, room): continue
			
			map.change_cell(temp_pos, -1)
	
	map.update_bitmask(shrunk.pos, shrunk.size)

####
# Islands
####
func fill_room(room):
	if not room: return
	if room.route.index <= 0: return
	
	var rect = room.rect
	var shrunk = rect.get_shrunk()
	if shrunk.size.x < 3 or shrunk.size.y < 3: return
	
	var area = rect.get_area()
	var num_islands = area
	
	for _i in range(num_islands):
		var rand_pos = shrunk.pos+Vector2(1,1) + (Vector2(randf(), randf()) * (shrunk.size-Vector2(1,1)*2)).floor()
		if not placement_allowed(rand_pos, room): continue
		
		map.change_cell(rand_pos, 0)
	
	map.update_bitmask_from_room(room)

####
# Slopes
####

func get_slopes(room):
	var slopes_created = []
	
	# add slopes in all four corner
	var shrunk = room.rect.shrunk
	if shrunk.size.x > 2 and shrunk.size.y > 2:
		slopes_created.append(shrunk.pos + Vector2(0, 0))
		slopes_created.append(shrunk.pos + Vector2(shrunk.size.x-1, 0))
		slopes_created.append(shrunk.pos + Vector2(shrunk.size.x-1, shrunk.size.y-1))
		slopes_created.append(shrunk.pos + Vector2(0, shrunk.size.y-1))
	
	return slopes_created

func place_slopes(room):
	for pos in get_slopes(room):
		if not placement_allowed(pos, room, false): continue
		map.change_cell(pos, 0)
	
	map.update_bitmask_from_room(room)

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

func tile_is_slope(pos):
	var tile_coord = tilemap.get_cell_autotile_coord(pos.x, pos.y)
	var tile_index = tile_coord.x + 12*tile_coord.y
	
	return (tile_index in allowed_slope_indices)

func get_slope_dir(pos):
	var tile_coord = tilemap.get_cell_autotile_coord(pos.x, pos.y)
	var tile_index = tile_coord.x + 12*tile_coord.y
	
	var array_idx = allowed_slope_indices.find(tile_index)
	if array_idx < 0: return Vector2.ZERO
	
	return allowed_slope_dirs[array_idx]

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