extends Node2D

# basic world parameters
const TILE_SIZE : float = 64.0
const WORLD_SIZE : Vector2 = Vector2(50, 30)
const BORDER_THICKNESS : int = 5

# the actual map
var map = []

onready var tilemap = $TileMap
onready var tilemap_copy = $MaskPainter/TilemapTexture/TileMapCopy
onready var route_generator = $RouteGenerator
onready var room_picker = $RoomPicker
onready var mask_painter = $MaskPainter
onready var edges = $Edges
onready var terrain = $Terrain
onready var special_elements = $SpecialElements
onready var slope_painter = $SlopePainter
onready var dynamic_tutorial = $DynamicTutorial
onready var player_progression = $PlayerProgression

onready var lock_module_layer = $LockModuleLayer

var num_teleporters_placed : int = 0

####
#
# Initialization
#
####
func generate():
	randomize()
	
	mask_painter.set_texture_size(WORLD_SIZE*TILE_SIZE)
	dynamic_tutorial.determine_included_types()
	
	initialize_grid()
	create_border_around_world()
	
	route_generator.set_global_parameters()
	route_generator.initialize_rooms()

func initialize_grid():
	map = []
	map.resize(WORLD_SIZE.x)

	for x in range(WORLD_SIZE.x):
		map[x] = []
		map[x].resize(WORLD_SIZE.y)
		
		for y in range(WORLD_SIZE.y):
			var pos = Vector2(x,y)
			
			change_cell(pos, 0)
			
			map[x][y] = {
				'pos': pos,
				'terrain': null,
				'edges': [null, null, null, null],
				'room': null,
				'special': null
			}

func create_border_around_world():
	# create an extra border around the world so we can never just go outside
	var border_size = BORDER_THICKNESS
	for x in range(-border_size, WORLD_SIZE.x+border_size):
		for y in range(border_size):
			change_cell(Vector2(x, -1-y), 0)
			change_cell(Vector2(x, WORLD_SIZE.y + y), 0)
	
	for y in range(-border_size, WORLD_SIZE.y+border_size):
		for x in range(border_size):
			change_cell(Vector2(-1-x,y), 0)
			change_cell(Vector2(WORLD_SIZE.x + x,y), 0)


# not sure if this should be here, but where else? SlopePainter? (rename to Tiles?)
func explode_cell(attacker, pos : Vector2):
	change_cell(pos, -1)
	attacker.coins.get_paid(1)
	attacker.map_painter.disable_paint = true
	mask_painter.clear_rectangle(pos*TILE_SIZE, Vector2(1,1)*TILE_SIZE)
	
	update_bitmask(pos-Vector2(2,2), Vector2(5,5))

####
#
# Checking neighbors/surroundings
#
####
func get_neighbor_tiles(pos, params):
	var nbs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	var res = []
	for i in range(nbs.size()):
		var new_pos = pos + nbs[i]
		var tile_data = tilemap.get_cellv(new_pos)
		
		if params.has('empty'):
			if tile_data >= 0: continue
		
		var obj = new_pos
		if params.has('return_with_dir'):
			obj = { 'pos': new_pos, 'dir': i }
		
		res.append(obj)
	
	return res

####
#
# Easily changing (or accessing) properties of cells
#
####
func change_cell(pos, id, flip_x = false, flip_y = false, transpose = false):
	tilemap.set_cellv(pos, id, flip_x, flip_y, transpose)
	tilemap_copy.set_cellv(pos, id, flip_x, flip_y, transpose)

func update_bitmask_from_room(room):
	var rect = room.rect
	update_bitmask(rect.pos, rect.size)

func update_bitmask(pos, size):
	var update_margin = Vector2(1,1)
	tilemap.update_bitmask_region(pos-update_margin, size+update_margin*2)
	tilemap_copy.update_bitmask_region(pos-update_margin, size+update_margin*2)

func get_cell(pos):
	return map[pos.x][pos.y]

func get_tilemap_at_real_pos(pos):
	var grid_pos = (pos / TILE_SIZE).floor()
	return tilemap.get_cellv(grid_pos)

func change_terrain_at(pos, type):
	if out_of_bounds(pos): return
	get_cell(pos).terrain = type

func get_full_dimensions():
	return {
		'x': -BORDER_THICKNESS*0.5 * TILE_SIZE,
		'y': -BORDER_THICKNESS*0.5 * TILE_SIZE,
		'width': (WORLD_SIZE.x+(BORDER_THICKNESS*2)*0.5) * TILE_SIZE,
		'height': (WORLD_SIZE.y+(BORDER_THICKNESS*2)*0.5) * TILE_SIZE
	}

####
#
# Helpers
#
####
func get_random_grid_pos():
	return Vector2(randi() % int(WORLD_SIZE.x), randi() % int(WORLD_SIZE.y))

func get_grid_pos(real_pos):
	return (real_pos / TILE_SIZE).floor()

func get_real_pos(pos):
	return pos*TILE_SIZE

func keep_within_bounds(pos : Vector2, allow_edge_overlap = false) -> Vector2:
	if pos.x < 0: pos.x = 0
	if pos.x >= WORLD_SIZE.x: 
		pos.x = WORLD_SIZE.x - 1
		if allow_edge_overlap: pos.x = WORLD_SIZE.x
	
	if pos.y < 0: pos.y = 0
	if pos.y >= WORLD_SIZE.y: 
		pos.y = WORLD_SIZE.y - 1
		if allow_edge_overlap: pos.y = WORLD_SIZE.y
	
	return pos

func get_vector_from_dir(d):
	var angle = d*0.5*PI
	return Vector2(cos(angle), sin(angle))

func get_dir_from_vector(vec):
	var angle = vec.angle()
	var epsilon = 0.003
	return floor( (angle * 4) / 2*PI + epsilon )

func get_cell_from_node(node):
	var grid_pos = (node.get_global_position() / float(TILE_SIZE)).floor()
	if out_of_bounds(grid_pos): return get_cell(Vector2.ZERO)
	return get_cell(grid_pos)

func get_room_at(pos):
	if out_of_bounds(pos): return null
	return get_cell(pos).room

func set_all_cells_to_room(room):
	for new_pos in room.rect.positions:
		if out_of_bounds(new_pos): continue

		var already_has_room = get_room_at(new_pos)
		if already_has_room and room.rect.inside_growth_area_global(new_pos): continue
		
		get_cell(new_pos).room = room

func remove_cells_from_room(room):
	for temp_pos in room.rect.positions:
		if out_of_bounds(temp_pos): continue
		
		var cur_room = get_room_at(temp_pos)
		if cur_room != room: continue
		
		get_cell(temp_pos).room = null

# If negative or 0, we're inside the world area (and not out of bounds)
# If positive, gives us the number of tiles we're out of bounds
func dist_to_bounds(pos):
	var x = max(0 - pos.x, pos.x - (WORLD_SIZE.x - 1))
	var y = max(0 - pos.y, pos.y - (WORLD_SIZE.y - 1))
	return max(x,y)

func dir_indices_to_bounds(pos, margin):
	var arr = []
	
	if pos.x < margin:
		arr.append(2)
	elif pos.x >= (WORLD_SIZE.x - margin):
		arr.append(0)
	
	if pos.y < margin:
		arr.append(3)
	elif pos.y >= (WORLD_SIZE.y - margin):
		arr.append(1)
	
	return arr

func out_of_bounds(pos):
	return pos.x < 0 or pos.x >= WORLD_SIZE.x or pos.y < 0 or pos.y >= WORLD_SIZE.y

func is_empty(pos):
	if out_of_bounds(pos): return false
	if not get_room_at(pos): return false
	return true
