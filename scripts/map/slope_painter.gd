extends Node

const REMOVE_THREE_WAY_PROB : float = 0.2

# list of tiles (in autotile) that represent a SLOPE and not a FILLED BLOCK
var allowed_slopes = [Vector2(1,0), Vector2(3,0), Vector2(8,0), Vector2(11,0), Vector2(1,2), Vector2(3,2), Vector2(8,3), Vector2(11,3)]
var allowed_slope_dirs = [Vector2(-1,-1), Vector2(1,-1), Vector2(-1,-1), Vector2(1,-1), Vector2(-1,1),Vector2(1,1), Vector2(-1,1), Vector2(1,1)]
var allowed_slope_indices = []

var allowed_items = [
	Vector2(0,0), Vector2(1,0), Vector2(2,0), Vector2(3,0), Vector2(5,0), Vector2(6,0), Vector2(8,0), Vector2(10,0), Vector2(11,0),
	Vector2(0,1), Vector2(1,1), Vector2(3,1), Vector2(4,1), Vector2(7,1), Vector2(8,1),
	Vector2(0,2), Vector2(1,2), Vector2(2,2), Vector2(3,2), Vector2(4,2), Vector2(7,2), Vector2(11,2),
	Vector2(1,3), Vector2(2,3), Vector2(3,3), Vector2(5,3), Vector2(6,3), Vector2(8,3), Vector2(9,3), Vector2(11,3)
]
var allowed_item_indices = []

# (0,0) (0,2) (1,3) (3,3)
var three_way_flat_indices = [0, 24, 37, 39]

onready var map = get_node("/root/Main/Map")
onready var tilemap = get_node("/root/Main/Map/TileMap")

func _ready():
	for slope in allowed_slopes:
		allowed_slope_indices.append(slope.x + 12*slope.y)
	
	for item in allowed_items:
		allowed_item_indices.append(item.x + 12*item.y)

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

# TO DO: This function can be HEAVILY optimized 
# And I need to figure out what the hell I'm even doing
func recalculate_room(room):
	if not room: return
	
	map.update_bitmask_from_room(room)
	
	# remove any slopes that turn out to not be slopes
	for pos in get_slopes(room):
		if tile_is_slope(pos): map.change_cell(pos, -1)
	
	# in fact, remove _any_ tiles that block stuff???
	for temp_pos in room.rect.shrunk_positions:
		if tilemap.get_cellv(temp_pos) == -1: continue
		if placement_allowed(temp_pos, room): continue
		
		map.change_cell(temp_pos, -1)
	
	# UPGRADE (pretty essential): it CAN happen that we have two 3-way tiles diagonally, which leaves only a tiny gap to move through
	# fix that
	for pos in room.rect.shrunk_positions:
		if not tile_is_three_way_flat(pos): continue
		var diagonals = [Vector2(1,1), Vector2(-1,1), Vector2(-1,-1), Vector2(1,-1)]
		
		for d in diagonals:
			if tile_is_three_way_flat(pos + d):
				map.change_cell(pos, -1)
				break
	
	# UPGRADE: we don't like those cells that are open on 3 sides, but flat
	# so if we encounter those, just remove them
	if GDict.cfg.remove_three_way_tiles:
		var remove_3_prob = REMOVE_THREE_WAY_PROB
		if G.in_tutorial_mode(): remove_3_prob = 1.0
		for pos in room.rect.positions:
			if not tile_is_three_way_flat(pos): continue
			if randf() > REMOVE_THREE_WAY_PROB: continue
			map.change_cell(pos, -1)

	map.update_bitmask_from_room(room)

####
# Islands
####
func clear_room(room):
	var positions = room.rect.shrunk_positions
	for pos in positions:
		map.change_cell(pos, -1)

func fill_room(room):
	if not room: return
	if room.route.index <= 0: return
	if map.room_picker.has_tutorial() and not map.room_picker.tutorial_course.tiles_inside_allowed: return
	if room.has_tutorial and GDict.cfg.dont_place_tiles_inside_rooms_with_tut: return
	
	var rect = room.rect
	var shrunk = rect.get_shrunk()
	if shrunk.size.x < 3 or shrunk.size.y < 3: return
	
	var area = rect.get_area()
	var ROOM_FILL_PERCENTAGE : float = 0.5
	var num_islands = ROOM_FILL_PERCENTAGE * area
	
	for _i in range(num_islands):
		var rand_pos = shrunk.pos+Vector2(1,1) + (Vector2(randf(), randf()) * (shrunk.size-Vector2(1,1)*2)).floor()
		if not placement_allowed(rand_pos, room): continue
		
		map.change_cell(rand_pos, 0)
	
	var holes_not_allowed = room.lock.lock_data.has("no_holes")
	
	if holes_not_allowed:
		for pos in room.rect.shrunk_positions:
			if room.tilemap.is_cell_filled(pos): continue
			
			var nbs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
			var num_filled_nbs = 0
			for nb in nbs:
				if room.tilemap.is_cell_filled(pos + nb): 
					num_filled_nbs += 1
			
			if num_filled_nbs >= 4:
				map.change_cell(pos, 0)

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

func tile_can_hold_item(pos):
	var tile_coord = tilemap.get_cell_autotile_coord(pos.x, pos.y)
	var tile_index = tile_coord.x + 12*tile_coord.y
	return (tile_index in allowed_item_indices)

# TO DO: not sure if this is the right one, maybe I'm missing half open stuff, or including too many this way
func tile_is_half_open(pos):
	return tile_is_slope(pos)

func tile_is_three_way_flat(pos):
	var tile_coord = tilemap.get_cell_autotile_coord(pos.x, pos.y)
	var tile_index = tile_coord.x + 12*tile_coord.y
	return (tile_index in three_way_flat_indices)

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
