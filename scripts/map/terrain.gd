extends Node

const CONSECUTIVE_SAME_TERRAINS_PROB : float = 0.25
const USE_REV_GRAVITY_ON_UP_DIR : float = 0.4

onready var map = get_parent()
onready var tilemap_terrain = $TileMapTerrain
onready var tutorial = get_node("/root/Main/Tutorial")
onready var route_generator = get_node("../RouteGenerator")

var available_terrains = []

func _ready():
	read_terrain_list_from_campaign()

func read_terrain_list_from_campaign():
	# TO DO: do what the function says
	available_terrains = GlobalDict.terrain_types.keys()
	
	available_terrains.erase("finish")
	available_terrains.erase("teleporter")
	
	for i in range(available_terrains.size()-1, -1, -1):
		var key = available_terrains[i]
		if terrain_is_lock(key):
			available_terrains.remove(i)
	
	print(available_terrains)

func terrain_is_lock(t):
	return t.right(t.length()-4) == "lock"

func on_new_room_created(room):
	var handout_terrains = (not tutorial.is_active()) and (not room.route.is_first_room())
	if not handout_terrains: return
	
	var rect_too_small = room.rect.get_area() < 4
	if rect_too_small: return
	
	if map.dynamic_tutorial.has_random('terrain', room):
		var rand_type = get_random_terrain_type(room)
		paint(room, rand_type)

func get_terrain_at_index(index):
	if index < 0: return ""
	return route_generator.cur_path[index].tilemap.terrain

func get_random_terrain_type(room):
	# RESTRICTION: place reverse gravity on things going up
	# TO DO: only if actually included in the list of terrains
	if room.route.dir == 3:
		if randf() <= USE_REV_GRAVITY_ON_UP_DIR:
			return "reverse_gravity"
	
	var last_terrain = get_terrain_at_index(room.route.index - 1)
	
	# UPGRADE: encourage using an IDENTICAL terrain multiple times in a row
	if last_terrain != "":
		if not GlobalDict.terrain_types[last_terrain].has('disable_consecutive') and not terrain_is_lock(last_terrain):
			if randf() <= CONSECUTIVE_SAME_TERRAINS_PROB:
				return last_terrain
	
	var key = "finish"
	var bad_choice = true
	
	var num_tries = 0
	var RESTRICTION_CUTOFF = 50
	var MAX_TRIES = 150
	
	while bad_choice:
		key = map.dynamic_tutorial.get_random('terrain', room)
		num_tries += 1
		
		if num_tries > MAX_TRIES:
			key = ""
			break
		
		if GlobalDict.terrain_types[key].has('unpickable'):
			continue
		
		# UPGRADE: don't allow two consecutive terrains of the same general category
		if last_terrain and num_tries < RESTRICTION_CUTOFF:
			if GlobalDict.terrain_types[last_terrain].category == GlobalDict.terrain_types[key].category:
				continue
		
		# RESTRICTION: No reverse gravity when going down
		if room.route.dir == 1 and key == "reverse_gravity":
			continue
		
		bad_choice = false
	
	return key

func paint(room, type):
	if not type or type == "": return
	
	var tile_id = -1
	if GlobalDict.terrain_types.has(type):
		tile_id = GlobalDict.terrain_types[type].frame

	var overwrites_terrain = GlobalDict.terrain_types[type].has('overwrite')
	
	var rect = room.rect
	for x in range(rect.size.x):
		for y in range(rect.size.y):
			var temp_pos = rect.pos + Vector2(x,y)
			
			var already_has_terrain = (tilemap_terrain.get_cellv(temp_pos) != -1) and map.get_room_at(temp_pos)
			var inside_growth_area = (x == 0 or x == (rect.size.x-1) or y == 0 or y == (rect.size.y - 1))
			
			if already_has_terrain and inside_growth_area:
				if not overwrites_terrain: continue
			
			tilemap_terrain.set_cellv(temp_pos, tile_id)
			map.change_terrain_at(temp_pos, type)
	
	room.tilemap.terrain = type
	
	map.dynamic_tutorial.on_usage_of('terrain', type)

func erase(room):
	var rect = room.rect
	for x in range(rect.size.x):
		for y in range(rect.size.y):
			var temp_pos = rect.pos + Vector2(x,y)
			var cell_room = map.get_room_at(temp_pos)
			if cell_room and cell_room != room: continue
			
			tilemap_terrain.set_cellv(temp_pos, -1)
			map.change_terrain_at(temp_pos, "")
	
	room.tilemap.terrain = ""

# TO DO: Create a function that paints a _specific tile/position_, 
# 		 or under a _specific condition_, not just all of them??

func someone_entered(node, terrain):
	var is_coin_terrain = (GlobalDict.terrain_types[terrain].category == "coin")
	if is_coin_terrain:
		node.get_node("Coins").show()

func someone_exited(node, terrain):
	pass
