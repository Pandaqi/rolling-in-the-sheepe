extends Node2D

# basic world parameters
const TILE_SIZE : float = 64.0
const WORLD_SIZE : Vector2 = Vector2(50, 30)
const BORDER_THICKNESS : int = 5

# the actual map
var map = []

onready var tilemap = $TileMap
onready var tilemap_copy = $MaskPainter/TilemapTexture/TileMapCopy
onready var tilemap_terrain = $TileMapTerrain
onready var mask_painter = $MaskPainter
onready var edges = $Edges

onready var tutorial = get_node("/root/Main/Tutorial")

onready var route_generator = $RouteGenerator

####
#
# Initialization
#
####
func generate():
	randomize()
	
	mask_painter.set_texture_size(WORLD_SIZE*TILE_SIZE)
	
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

####
#
# Easily changing (or accessing) properties of cells
#
####
func change_cell(pos, id, flip_x = false, flip_y = false, transpose = false):
	tilemap.set_cellv(pos, id, flip_x, flip_y, transpose)
	tilemap_copy.set_cellv(pos, id, flip_x, flip_y, transpose)

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
		'x': -BORDER_THICKNESS * TILE_SIZE,
		'y': -BORDER_THICKNESS * TILE_SIZE,
		'width': (WORLD_SIZE.x+(BORDER_THICKNESS*2)) * TILE_SIZE,
		'height': (WORLD_SIZE.y+(BORDER_THICKNESS*2)) * TILE_SIZE
	}

####
#
# Helpers
#
####
func get_random_grid_pos():
	return Vector2(randi() % int(WORLD_SIZE.x), randi() % int(WORLD_SIZE.y))

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
	return get_cell(pos).room

func set_all_cells_to_room(r):
	for x in range(r.size.x):
		for y in range(r.size.y):
			var new_pos = r.pos + Vector2(x,y)
			get_cell(new_pos).room = r

# If negative or 0, we're inside the world area (and not out of bounds)
# If positive, gives us the number of tiles we're out of bounds
func dist_to_bounds(pos):
	var x = max(0 - pos.x, pos.x - (WORLD_SIZE.x - 1))
	var y = max(0 - pos.y, pos.y - (WORLD_SIZE.y - 1))
	return max(x,y)

func out_of_bounds(pos):
	return pos.x < 0 or pos.x >= WORLD_SIZE.x or pos.y < 0 or pos.y >= WORLD_SIZE.y

func is_empty(pos):
	if out_of_bounds(pos): return false
	if not get_room_at(pos): return false
	return true
