extends Node

const TILE_SIZE : float = 64.0

var pos : Vector2
var size : Vector2

var prev_room
var dir : int

var num_tiles_before_us : int

var has_border : bool = false

var tilemap : TileMap
var tilemap_terrain : TileMap
var map

var terrain_types = {
	"finish": { "frame": 0, 'unpickable': true },
	"lock": { "frame": 1, 'unpickable': true },
	"teleporter": { "frame": 2, 'unpickable': true },
	"reverse_gravity": { "frame": 3 },
	"no_gravity": { "frame": 4 },
	"ice": { "frame": 5 },
	"bouncy": { "frame": 6 },
	"spiderman": { "frame": 7 },
	"speed_boost": { "frame": 8 },
	"speed_slowdown": { "frame": 9 },
	"glue": { "frame": 10 },
	"reverse_controls": { "frame": 11 },
	"spikes": { "frame": 12 },
	"ghost": { "frame": 13 }
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

func get_real_pos():
	return pos * TILE_SIZE

func set_size(new_size):
	size = new_size

func get_real_size():
	return size*TILE_SIZE

func get_random_size(require_large_size = false, require_small_size = false):
	if require_large_size:
		return Vector2(randi() % 3 + 3, randi() % 3 + 3)
	elif require_small_size:
		return Vector2(randi() % 2 + 1, randi() % 2 + 1)
	
	return Vector2(randi() % 3 + 1, randi() % 3 + 1)

func set_random_size(require_large_size = false, require_small_size = false):
	set_size(get_random_size(require_large_size, require_small_size))

func get_bottom_right():
	return pos + size

func get_center():
	return (pos + 0.5*size)*TILE_SIZE

func get_longest_side():
	return max(size.x, size.y)

func make_local(p):
	p /= TILE_SIZE
	return p

#####
#
# For workig with our (relative) position within the current route
#
#####
func set_dir(d):
	dir = d

func set_path_position(num):
	num_tiles_before_us = num

func tiled_dist_to(other_room):
	return (other_room.num_tiles_before_us - num_tiles_before_us)

func set_previous_room(r):
	prev_room = r
	delete_edges_inside()
	open_connection_to_previous_room()

func get_previous_room():
	return prev_room

func delete_edges_inside():
	for x in range(size.x):
		for y in range(size.y):
			for i in range(4):
				var edge = { 'pos': pos + Vector2(x,y), 'dir_index': i }
				var link = edge_links_to(edge)
				if not link or link != self: continue
				
				map.remove_edge_at(edge.pos, edge.dir_index)

func open_connection_to_previous_room():
	if not prev_room: return
	if prev_room.has_lock(): return
	
	var outline = determine_outline()
	for edge in outline:
		if not edge_links_to_previous_room(edge): continue

		map.remove_edge_at(edge.pos, edge.dir_index)

func create_border_around_us(params = {}):
	var outline = determine_outline()
	
	var type = "lock"
	if params.has('type'): type = params.type
	
	for edge in outline:
		var other_side = edge_links_to(edge)
		if params.has('open_all_linked_edges'):
			if other_side and not (other_side == self): 
				continue
		elif prev_room:
			if other_side == prev_room and (not prev_room.has_lock()): 
				continue
		
		# @params => position, index (which direction), type of edge
		map.set_edge_at(edge.pos, edge.dir_index, type)
	
	has_border = true

func remove_border_around_us():
	var outline = determine_outline()
	for edge in outline:
		map.remove_edge_at(edge.pos, edge.dir_index)

func edge_links_to(edge):
	var opposite_grid_pos = edge.pos + map.get_vector_from_dir(edge.dir_index)
	if map.out_of_bounds(opposite_grid_pos): return null
	
	return map.get_cell(opposite_grid_pos).room

func edge_links_to_previous_room(edge):
	if not get_previous_room(): return false
	
	return (edge_links_to(edge) == get_previous_room())

#####
#
# (Physics) Helper functions
#
#####
func has_real_point(p : Vector2) -> bool:
	return p.x >= pos.x*TILE_SIZE and p.x <= (pos.x+size.x)*TILE_SIZE and p.y >= pos.y*TILE_SIZE and p.y <= (pos.y+size.y)*TILE_SIZE

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
# Terrain stuff
#
#####
func get_random_terrain_type():
	var key = "finish"
	var all_keys = terrain_types.keys()
	while terrain_types[key].has('unpickable'):
		key = all_keys[randi() % all_keys.size()]
	
	return key

func give_terrain_if_wanted():
	if size.x <= 1 and size.y <= 1: return
	
	paint_terrain(get_random_terrain_type())

#####
#
# Tilemap operations
#
#####
func delete():
	if lock_module: lock_module.delete()
	
	fill_tiles()
	clear_area_in_paint_mask()
	remove_references_in_map()

# NOTE: I add half size here because the "paint circles" of course will EXTEND slightly beyond the room borders, as they are circles
func clear_area_in_paint_mask():
	map.mask_painter.clear_rectangle((pos-Vector2(0.5,0.5))*TILE_SIZE, (size+ Vector2(1,1))*TILE_SIZE)

# NOTE: It can happen that tiles inside of us do NOT belong to us anymore
# (e.g. the teleporter overlaps older rooms), so only delete those that still DO
func remove_references_in_map():
	for x in range(size.x):
		for y in range(size.y):
			var temp_pos = pos + Vector2(x,y)
			var cur_room = map.get_cell(temp_pos).room
			
			if cur_room != self: continue
			
			map.get_cell(temp_pos).room = null

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
			map.change_cell(temp_pos, tile_id)
	
	map.update_bitmask(pos, size)

func copy_and_grow(val, keep_within_bounds = false):
	var copy = get_script().new()
	copy.init(map, tilemap, tilemap_terrain)
	
	copy.set_pos(pos - Vector2(1,1)*val)
	copy.set_size(size+Vector2(1,1)*2*val)
	
	if keep_within_bounds:
		copy.pos = map.keep_within_bounds(copy.pos)
		copy.size = map.keep_within_bounds(copy.pos + copy.size, true) - copy.pos
	
	return copy

#####
#
# Section locks
#
#####
func has_lock():
	return (lock_module != null)

func add_lock():
	if not has_border:
		create_border_around_us()
	
	paint_terrain("lock")
	
	# TO DO: actually select random lock type from list (once we have more)
	var rand_type = "coin"
	var scene = load("res://scenes/locks/" + rand_type + "_lock.tscn").instance()
	scene.my_room = self
	map.add_child(scene)
	
	lock_module = scene
	
	print("Should add lock now")

func remove_lock():
	remove_border_around_us()
	
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
	create_border_around_us({ 'open_all_linked_edges': true })
	
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
	
	var grown_rect = copy_and_grow(1, true)
	
	for x in range(grown_rect.size.x):
		for y in range(grown_rect.size.y):
			var temp_pos = grown_rect.pos + Vector2(x,y)
			
			var already_has_terrain = (tilemap_terrain.get_cellv(temp_pos) != -1) and map.get_room_at(temp_pos)
			
			if already_has_terrain:
				var room_came_later_than_us = (map.get_room_at(temp_pos).num_tiles_before_us > self.num_tiles_before_us)
				if room_came_later_than_us:
					if type != "teleporter": 
						continue
			
			tilemap_terrain.set_cellv(temp_pos, tile_id)
			map.change_terrain_at(temp_pos, type)

# TO DO: Create a function that paints a _specific tile/position_, 
# 		 or under a _specific condition_, not just all of them
