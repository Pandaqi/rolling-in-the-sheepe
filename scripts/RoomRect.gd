extends Node

const TILE_SIZE : float = 64.0

var players_inside = []

var index : int
var pos : Vector2
var size : Vector2

# a shrunken version of ourselves (by 1), which is the "real" room
# (the original grown version is used for better terrain painting and overlap checking)
var shrunk = {}
var outline = []

var prev_room
var dir : int

var num_tiles_before_us : int
var terrain : String = ""

var has_border : bool = false

var tiles_inside = []
var special_elements = []

var map

var lock_module

#####
#
# Default properties: position and size
#
#####
func init(map_reference):
	set_pos(Vector2.ZERO)
	set_random_size()
	
	map = map_reference

func set_index(num):
	index = num

func set_pos(new_pos):
	pos = new_pos

func get_real_pos():
	return pos * TILE_SIZE

func set_size(new_size):
	size = new_size

func get_area():
	return shrunk.size.x*shrunk.size.y

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
# Keeping track of the players inside
#
#####
func add_player(p):
	players_inside.append(p)

func remove_player(p):
	players_inside.erase(p)

#####
#
# For working with our (relative) position within the current route
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

func get_previous_room():
	return prev_room

func delete_edges_inside():
	for x in range(shrunk.size.x):
		for y in range(shrunk.size.y):
			for i in range(4):
				var edge = { 'pos': shrunk.pos + Vector2(x,y), 'dir_index': i }
				var link = edge_links_to(edge)
				if not link or link != self: continue
				
				map.edges.remove_at(edge.pos, edge.dir_index)

func open_connection_to_previous_room():
	if not prev_room: return
	if prev_room.has_lock(): return

	for edge in outline:
		if not edge_links_to_previous_room(edge): continue

		map.edges.remove_at(edge.pos, edge.dir_index)

func create_border_around_us(params = {}):
	var type = "lock"
	if params.has('type'): type = params.type
	
	for edge in outline:
		var other_side = edge_links_to(edge)
		if params.has('open_all_linked_edges'):
			if other_side and not (other_side == self): 
				map.edges.remove_at(edge.pos, edge.dir_index)
				continue
		elif prev_room:
			if other_side == prev_room and (not prev_room.has_lock()):
				map.edges.remove_at(edge.pos, edge.dir_index) 
				continue
		
		# @params => position, index (which direction), type of edge
		map.edges.set_at(edge.pos, edge.dir_index, type)
	
	has_border = true

func remove_border_around_us():
	for edge in outline:
		map.edges.remove_at(edge.pos, edge.dir_index)

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
	
	return (shrunk.pos + Vector2(randf(), randf()) * shrunk.size)*TILE_SIZE

func get_free_real_pos_inside():
	var rand_pos
	var bad_choice = true
	
	while bad_choice:
		rand_pos = shrunk.pos + Vector2(randi() % int(shrunk.size.x), randi() % int(shrunk.size.y))
		bad_choice = (map.tilemap.get_cellv(rand_pos) != -1)
	
	return (rand_pos + Vector2(0.5, 0.5))*TILE_SIZE

#####
#
# Tilemap operations
#
#####
func delete():
	if lock_module: lock_module.delete()
	
	fill_tiles()
	map.terrain.erase(self)
	map.remove_cells_from_room(self)
	
	# NOTE: I add half size here because the "paint circles" of course will EXTEND slightly beyond the room borders, as they are circles
	map.mask_painter.clear_rectangle((pos-Vector2(0.5,0.5))*TILE_SIZE, (size+ Vector2(1,1))*TILE_SIZE)

func erase_tiles():
	change_tiles_to(-1)

func fill_tiles():
	change_tiles_to(0)

func change_tiles_to(tile_id : int = -1):
	for x in range(shrunk.size.x):
		for y in range(shrunk.size.y):
			var temp_pos = shrunk.pos + Vector2(x,y)
			if map.out_of_bounds(temp_pos): continue
			map.change_cell(temp_pos, tile_id)
	
	map.update_bitmask(pos, size)

func copy_and_grow(val, keep_within_bounds = false):
	var copy = get_script().new()
	copy.init(map)
	
	copy.set_pos(pos - Vector2(1,1)*val)
	copy.set_size(size+Vector2(1,1)*2*val)
	
	if keep_within_bounds:
		copy.pos = map.keep_within_bounds(copy.pos)
		copy.size = map.keep_within_bounds(copy.pos + copy.size, true) - copy.pos
	
	return copy

#####
#
# Special items ( = any special elements inside)
#
#####
func determine_tiles_inside():
	tiles_inside = []
	
	for x in range(size.x):
		for y in range(size.y):
			var temp_pos = pos + Vector2(x,y)
			if map.tilemap.get_cellv(temp_pos) == -1: continue
			
			tiles_inside.append(temp_pos)

func get_free_tile_inside():
	tiles_inside.shuffle()
	for tile in tiles_inside:
		if map.get_cell(tile).special: continue
		
		return tile

func add_special_item():
	# TO DO: find actual good requirements for this
	var fit_for_special_item = (get_area() >= 9)
	
	if not fit_for_special_item: return
	
	# determine type (if possible; if not, abort)
	var type = map.special_elements.get_random_type()
	if not type: return
	
	# create the actual item
	var item = load("res://scenes/elements/" + type + ".tscn").instance()
	
	# determine location
	var location = get_free_tile_inside()
	item.set_position(location * map.TILE_SIZE)
	
	# TO DO: determine rotation (based on neighbors OR slope dir)
	
	# ask map to place and remember us
	var item_obj = { 'item': item, 'type': type, 'pos': location }
	map.special_elements.place(item_obj)
	special_elements.append(item_obj)

func clear_special_items():
	for item in special_elements:
		map.special_elements.clear(item)

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
	
	map.terrain.paint(self, "lock")
	
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

func determine_outline():
	var arr = []
	
	# top and bottom cells
	for x in range(shrunk.size.x):
		arr.append({ 'pos': shrunk.pos + Vector2(x,0), 'dir_index': 3 })
		arr.append({ 'pos': shrunk.pos + Vector2(x,shrunk.size.y-1), 'dir_index': 1 })
	
	# left and right cells
	for y in range(shrunk.size.y):
		arr.append({ 'pos': shrunk.pos + Vector2(shrunk.size.x-1,y), 'dir_index': 0 })
		arr.append({ 'pos': shrunk.pos + Vector2(0,y), 'dir_index': 2 })
	
	outline = arr
	
	# DEBUGGING
	#delete_edges_inside()
	
	open_connection_to_previous_room()

#####
#
# Special rooms
#
#####
func turn_into_teleporter():
	update_map_to_new_rect()

	lock_module = load("res://scenes/locks/teleporter.tscn").instance()
	lock_module.my_room = self
	map.add_child(lock_module)

	map.terrain.paint(self, "teleporter")
	create_border_around_us({ 'open_all_linked_edges': true })

func update_map_to_new_rect():
	map.set_all_cells_to_room(self)
	erase_tiles()
