extends Node

const TILE_SIZE : float = 64.0

var pos : Vector2
var size : Vector2

var tilemap : TileMap
var tilemap_terrain : TileMap
var map

var terrain_types = {
	"finish": { "frame": 0 },
	"lock": { "frame": 1 },
	"teleporter": { "frame": 2 }
}

var lock_module

#####
#
# Default properties: position and size
#
#####
func init(map_reference, tm, tm_terrain):
	set_pos(Vector2.ZERO)
	set_random_size()
	
	map = map_reference
	tilemap = tm
	tilemap_terrain = tm_terrain

func set_pos(new_pos):
	pos = new_pos

func set_size(new_size):
	size = new_size

func get_random_size(require_large_size = false, require_small_size = false):
	if require_large_size:
		return Vector2(randi() % 3 + 3, randi() % 3 + 3)
	elif require_small_size:
		return Vector2(randi() % 2 + 1, randi() % 2 + 1)
	
	return Vector2(randi() % 3 + 1, randi() % 3 + 1)

func set_random_size(require_large_size = false, require_small_size = false):
	set_size(get_random_size(require_large_size, require_small_size))

func get_bottom_right():
	return pos+size

func get_center():
	return (pos + 0.5*size)*TILE_SIZE

func get_longest_side():
	return max(size.x, size.y)

func make_local(p):
	p /= TILE_SIZE
	return p

#####
#
# (Physics) Helper functions
#
#####
func has_point(p : Vector2) -> bool:
	p = make_local(p)
	return p.x >= pos.x and p.x <= (pos.x+size.x) and p.y >= pos.y and p.y <= (pos.y+size.y)

func overlaps(rect) -> bool:
	return (pos.x < rect.get_bottom_right().x and rect.pos.x < get_bottom_right().x) and pos.y < rect.get_bottom_right().y and rect.pos.y < get_bottom_right().y

func get_random_real_position_inside(params = {}):
	if params.has('empty'):
		return get_free_real_pos_inside() + 0.8*Vector2(randf()-0.5, randf()-0.5*TILE_SIZE)
	
	return (pos + Vector2(randf(), randf()) * size)*TILE_SIZE

func get_free_real_pos_inside():
	var rand_pos
	var bad_choice = true
	
	while bad_choice:
		rand_pos = pos + Vector2(randi() % int(size.x), randi() % int(size.y))
		bad_choice = (tilemap.get_cellv(rand_pos) != -1)
	
	return (rand_pos + Vector2(0.5, 0.5))*TILE_SIZE

#####
#
# Tilemap operations
#
#####
func delete():
	if lock_module: lock_module.delete()
	
	fill_tiles()

func erase_tiles():
	change_tiles_to(-1)

func fill_tiles():
	change_tiles_to(0)
	paint_terrain("")

func change_tiles_to(tile_id : int = -1):
	for x in range(size.x):
		for y in range(size.y):
			var temp_pos = pos + Vector2(x,y)
			if map.out_of_bounds(temp_pos): continue
			tilemap.set_cellv(temp_pos, tile_id)

func copy_and_grow(val, keep_within_bounds = false):
	var copy = get_script().new()
	copy.init(map, tilemap, tilemap_terrain)
	
	copy.set_pos(pos - Vector2(1,1)*val)
	copy.set_size(size+Vector2(1,1)*2*val)
	
	if keep_within_bounds:
		copy.pos = map.keep_within_bounds(copy.pos)
		copy.size = map.keep_within_bounds(copy.pos + copy.size) - copy.pos
	
	return copy

#####
#
# Section locks
#
#####
func add_lock():
	var outline = determine_outline()
	var previous_room = map.get_path_from_front(1)
	for edge in outline:
		var opposite_grid_pos = edge.pos + map.get_vector_from_dir(edge.dir_index)
		var opposite_real_pos = opposite_grid_pos * TILE_SIZE
		
		if previous_room:
			var other_side_is_open = previous_room.has_point(opposite_real_pos)
			if other_side_is_open: 
				continue
		
		# @params => position, index (which direction), type of edge
		map.set_edge_at(edge.pos, edge.dir_index, "lock")
	
	paint_terrain("lock")
	
	# TO DO: actually select random lock type from list (once we have more)
	var rand_type = "coin"
	var scene = load("res://scenes/locks/" + rand_type + "_lock.tscn").instance()
	scene.my_room = self
	map.add_child(scene)
	
	lock_module = scene
	
	print("Should add lock now")

func remove_lock():
	var outline = determine_outline()
	for edge in outline:
		map.remove_edge_at(edge.pos, edge.dir_index)
	
	lock_module = null
	
	print("Should remove lock now")

func determine_outline(params = {}):
	var arr = []
	
	# top and bottom cells
	for x in range(size.x):
		arr.append({ 'pos': pos + Vector2(x,0), 'dir_index': 3 })
		arr.append({ 'pos': pos + Vector2(x,size.y-1), 'dir_index': 1 })
	
	# left and right cells
	for y in range(size.y):
		arr.append({ 'pos': pos + Vector2(size.x-1,y), 'dir_index': 0 })
		arr.append({ 'pos': pos + Vector2(0,y), 'dir_index': 2 })
	
	return arr

#####
#
# Special rooms
#
#####
func turn_into_teleporter():
	# grow room if it's too small (to hold players)
	# TO DO: go via the GROW function, don't allow extending past bounds
	var num_tries = 0
	var max_tries = 2
	
	while size.x < 3 or size.y < 3:
		var grown = copy_and_grow(1, true)
		
		pos = grown.pos
		size = grown.size
		
		num_tries += 1
		if num_tries >= max_tries: break
	
	update_map_to_new_rect()

	paint_terrain("teleporter")
	
	lock_module = load("res://scenes/locks/teleporter.tscn").instance()
	lock_module.my_room = self
	map.add_child(lock_module)

func update_map_to_new_rect():
	map.set_room_at(pos, self)
	erase_tiles()

#####
#
# Terrain painting
# (behind the tilemap is another tilemap holding terrain, which influences how you move/operate in a certain section)
#
#####
func paint_terrain(type):
	var tile_id = -1
	if terrain_types.has(type):
		tile_id = terrain_types[type].frame
	
	for x in range(size.x):
		for y in range(size.y):
			var temp_pos = pos + Vector2(x,y)
			tilemap_terrain.set_cellv(temp_pos, tile_id)
			map.change_terrain_at(temp_pos, type)

# TO DO: Create a function that paints a _specific tile/position_, 
# 		 or under a _specific condition_, not just all of them
