extends Node

const TILE_SIZE : float = 64.0

var pos : Vector2
var size : Vector2

var tilemap : TileMap
var tilemap_terrain : TileMap
var map

var terrain_types = {
	"finish": { "frame": 0 }
}

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

#####
#
# Tilemap operations
#
#####
func erase_tiles():
	change_tiles_to(-1)

func fill_tiles():
	change_tiles_to(0)

func change_tiles_to(tile_id : int = -1):
	for x in range(size.x):
		for y in range(size.y):
			var temp_pos = pos + Vector2(x,y)
			tilemap.set_cellv(temp_pos, tile_id)

func copy_and_grow(val):
	var copy = get_script().new()
	copy.init(map, tilemap, tilemap_terrain)
	
	copy.set_pos(pos - Vector2(1,1)*val)
	copy.set_size(size+Vector2(1,1)*2*val)
	
	return copy

#####
#
# Section locks
#
#####
func add_lock():
	print("Should add lock now")

#####
#
# Terrain painting
# (behind the tilemap is another tilemap holding terrain, which influences how you move/operate in a certain section)
#
#####
func paint_terrain(type):
	print("Should add terrain: " + type)
	
	var tile_id = terrain_types[type].frame
	
	for x in range(size.x):
		for y in range(size.y):
			var temp_pos = pos + Vector2(x,y)
			tilemap_terrain.set_cellv(temp_pos, tile_id)
			map.change_terrain_at(temp_pos, type)

# TO DO: Create a function that paints a _specific tile/position_, 
# 		 or under a _specific condition_, not just all of them
