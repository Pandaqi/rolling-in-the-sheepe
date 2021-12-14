extends Node

const TILE_SIZE : float = 64.0

var pos : Vector2
var size : Vector2

var positions : Array = []
var shrunk_positions : Array = []

# a shrunken version of ourselves (by 1), which is the "real" room
# (the original grown version is used for better terrain painting and overlap checking)
var shrunk = {}

onready var map = get_node("/root/Main/Map")

func update_from(new_rect):
	set_pos(new_rect.pos)
	set_size(new_rect.size)
	
	update_positions_array()

func update_positions_array():
	positions = []
	for x in range(size.x):
		for y in range(size.y):
			positions.append(pos + Vector2(x,y))

func update_shrunk_positions_array():
	shrunk_positions = []
	for x in range(shrunk.size.x):
		for y in range(shrunk.size.y):
			shrunk_positions.append(shrunk.pos + Vector2(x,y))

func set_pos(new_pos):
	pos = new_pos

func get_real_pos():
	return pos * TILE_SIZE

func get_real_shrunk_pos():
	return shrunk.pos * TILE_SIZE

func set_size(new_size):
	size = new_size

func get_area():
	return shrunk.size.x*shrunk.size.y

func get_real_shrunk_size():
	return shrunk.size*TILE_SIZE

func get_real_size():
	return size*TILE_SIZE

func get_center():
	return (pos + 0.5*size)*TILE_SIZE

func get_longest_side():
	return max(size.x, size.y)

func make_local(p):
	p /= TILE_SIZE
	return p

func get_shrunk():
	return shrunk

func save_cur_size_as_shrunk():
	shrunk = { 'pos': pos, 'size': size }
	update_shrunk_positions_array()

func inside_growth_area(p:Vector2):
	return (p.x == 0 or p.x == (size.x-1) or p.y == 0 or p.y == (size.y - 1))

func inside_growth_area_global(p:Vector2):
	return inside_growth_area(p - pos)

#func has_real_point(p : Vector2) -> bool:
#	return p.x >= pos.x*TILE_SIZE and p.x <= (pos.x+size.x)*TILE_SIZE and p.y >= pos.y*TILE_SIZE and p.y <= (pos.y+size.y)*TILE_SIZE
#
#func has_point(p : Vector2) -> bool:
#	p = make_local(p)
#	return p.x >= pos.x and p.x <= (pos.x+size.x) and p.y >= pos.y and p.y <= (pos.y+size.y)

#func get_random_size(require_large_size = false, require_small_size = false):
#	if require_large_size:
#		return Vector2(randi() % 3 + 3, randi() % 3 + 3)
#	elif require_small_size:
#		return Vector2(randi() % 2 + 1, randi() % 2 + 1)
#
#	return Vector2(randi() % 3 + 1, randi() % 3 + 1)
#
#func set_random_size(require_large_size = false, require_small_size = false):
#	set_size(get_random_size(require_large_size, require_small_size))
#
#func get_bottom_right():
#	return pos + size

func get_random_real_pos_inside(params = {}):
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

#func copy_and_grow(val, keep_within_bounds = false):
#	var copy = get_script().new()
#	copy.init(map)
#
#	copy.set_pos(pos - Vector2(1,1)*val)
#	copy.set_size(size+Vector2(1,1)*2*val)
#
#	if keep_within_bounds:
#		copy.pos = map.keep_within_bounds(copy.pos)
#		copy.size = map.keep_within_bounds(copy.pos + copy.size, true) - copy.pos
#
#	return copy

func big_enough_for_tutorial():
	return get_area() >= 9

func get_mask_data():
	return {
		'pos': (pos - Vector2(0.5,0.5))*TILE_SIZE, 
		'size': (size + Vector2(1,1))*TILE_SIZE
	}
