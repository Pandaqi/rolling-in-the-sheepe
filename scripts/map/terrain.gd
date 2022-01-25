extends Node2D

const CONSECUTIVE_SAME_TERRAINS_PROB : float = 0.25
const USE_REV_GRAVITY_ON_UP_DIR : float = 0.85

onready var map = get_parent()
onready var solo_mode = get_node("/root/Main/SoloMode")
onready var tilemap_terrain = $TileMapTerrain

# NOTE: this only updates when terrain is actually painted
# this way, we skip tiny (empty) rooms when doing a "consecutive terrain" check
# but we DO reset it if we haven't had a terrain in too long
var last_terrain : String = ""
var num_terrainless_rooms_in_sequence : int = 0

func terrain_is_lock(t):
	return t.right(t.length()-4) == "lock"

func on_new_room_created(room):
	var handout_terrains = not room.route.is_first_room()
	if not handout_terrains: return
	
	var rect_too_small = room.rect.get_area() < 4
	if rect_too_small: 
		num_terrainless_rooms_in_sequence += 1
		if num_terrainless_rooms_in_sequence > 3: last_terrain = ""
		return
	
	if map.dynamic_tutorial.has_random('terrain', room):
		var rand_type = get_random_terrain_type(room)
		paint(room, rand_type)
		num_terrainless_rooms_in_sequence = 0

func get_terrain_at_index(index):
	if index < 0: return ""
	return map.route_generator.cur_path[index].tilemap.terrain

func get_random_terrain_type(room):
	# RESTRICTION: place reverse gravity on things going up
	# (even if not explained (yet), this is the way to go)
	if room.route.dir == 3:
		if randf() <= USE_REV_GRAVITY_ON_UP_DIR:
			return "reverse_gravity"

	# UPGRADE: encourage using an IDENTICAL terrain multiple times in a row
	if last_terrain != "":
		var consecutive_allowed = not GDict.terrain_types[last_terrain].has('disable_consecutive')
		var pickable = not is_unpickable(last_terrain)
		
		if consecutive_allowed and pickable:
			if randf() <= CONSECUTIVE_SAME_TERRAINS_PROB:
				return last_terrain
	
	var key = "finish"
	var bad_choice = true
	
	var num_tries = 0
	var RESTRICTION_CUTOFF = 50
	var MAX_TRIES = 150
	
	while bad_choice:
		key = map.dynamic_tutorial.get_random('terrain', room)
		if not key:
			key = ""
			break
		
		num_tries += 1
		
		if num_tries > MAX_TRIES:
			key = ""
			break
		
		if is_unpickable(key):
			continue
		
		# UPGRADE: don't allow two consecutive terrains of the same general category
		if last_terrain == key: continue
		if last_terrain and num_tries < RESTRICTION_CUTOFF:
			if GDict.terrain_types[last_terrain].category == GDict.terrain_types[key].category:
				continue
		
		# RESTRICTION: No reverse gravity when going down
		if room.route.dir == 1 and key == "reverse_gravity":
			continue
		
		bad_choice = false
	
	return key

func paint(room, type):
	if not type or type == "": return
	
	last_terrain = type
	
	var tile_id = -1
	if GDict.terrain_types.has(type):
		tile_id = GDict.terrain_types[type].frame

	var overwrites_terrain = GDict.terrain_types[type].has('overwrite')
	
	var rect = room.rect
	for temp_pos in rect.positions:
		var already_has_terrain = (tilemap_terrain.get_cellv(temp_pos) != -1) and map.get_room_at(temp_pos)
		var inside_growth_area = rect.inside_growth_area_global(temp_pos)
		
		if already_has_terrain and inside_growth_area:
			if not overwrites_terrain: continue
		
		tilemap_terrain.set_cellv(temp_pos, tile_id)
		map.change_terrain_at(temp_pos, type)
	
	room.tilemap.terrain = type
	
	map.dynamic_tutorial.on_usage_of('terrain', type)

func erase(room):
	var rect = room.rect
	for temp_pos in rect.positions:
		var cell_room = map.get_room_at(temp_pos)
		if cell_room and cell_room != room: continue
		
		tilemap_terrain.set_cellv(temp_pos, -1)
		map.change_terrain_at(temp_pos, "")
	
	room.tilemap.terrain = ""

func someone_entered(node, terrain):
	var is_coin_terrain = (GDict.terrain_types[terrain].has('coin_related'))
	if is_coin_terrain: node.get_node("Coins").show()

func someone_exited(_node, _terrain):
	pass

func is_unpickable(type : String):
	return GDict.terrain_types[type].has("unpickable") or (solo_mode.is_active() and GDict.terrain_types[type].has("solo_upickable"))
