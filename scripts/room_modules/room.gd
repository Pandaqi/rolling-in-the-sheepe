extends Node2D

# global nodes
onready var map = get_node("/root/Main/Map")
onready var route_generator = get_node("/root/Main/Map/RouteGenerator")
onready var slope_painter = get_node("/root/Main/Map/SlopePainter")
onready var main_particles = get_node("/root/Main/Particles")

# modules
onready var rect = $Rect
onready var entities = $Entities
onready var lock = $Lock
onready var outline = $Outline
onready var route = $Route
onready var tilemap = $Tilemap
onready var items = $Items

var has_tutorial : bool = false
var is_finish : bool = false
var related_items : Array = []

func initialize(pos, size):
	rect.set_pos(pos)
	rect.set_size(size)

func delete():
	lock.delete(true) # @param hard_remove
	tilemap.delete()
	items.delete()
	entities.delete()
	
	outline.remove_border_around_us()
	
	for node in related_items:
		node.queue_free()

func connect_related_item(node):
	related_items.append(node)

# NOTE: called AFTER the whole placement for this room is done
func turn_into_finish():
	is_finish = true
	map.terrain.paint(self, "finish")
	outline.create_border_around_us({ 'type': 'finish' })
	
	map.route_generator.placed_finish()
	
	# nothing comes after the finish anymore, so do this ourselves
	finish_placement_in_hindsight()

func turn_into_teleporter():
	
	# if too small for a reasonable teleporter, increase
	# (if big enough, this isn't desirable, as it might open stuff to older rooms)
	if rect.get_area() <= 9:
		rect.save_cur_size_as_shrunk()
		var grown_rect = {
			'pos': rect.pos-Vector2.ONE, 
			'size': rect.size + Vector2.ONE*2
		}
		rect.update_from(grown_rect)
	
	finish_placement()
	finish_placement_in_hindsight()
	
	tilemap.update_map_to_new_rect()
	lock.add_teleporter()
	
	if map.num_teleporters_placed <= 0:
		map.dynamic_tutorial.place_tutorial(self)
	
	map.num_teleporters_placed += 1

func place(params):
	# we AUTO-GROW rooms by 1 when saving them in the map (and painting terrain)
	# This ensures we also get a good background on slopes and other "transparent" autotiles
	# And also (hopefully) ensures betters separation of rooms
	rect.save_cur_size_as_shrunk()
	rect.set_pos(rect.pos - Vector2(1,1))
	rect.set_size(rect.size + Vector2(1,1)*2)
	rect.update_positions_array()
	
	# DEBUGGING
	print("RECT PLACED")
	print({ 'pos': rect.pos, 'size': rect.size })
	#print(rect.shrunk)

	route.set_index(params.index)
	route.set_previous_room(params.prev_room)
	route.set_dir(params.dir)
	route.set_path_position(params.path_pos)
	
	map.terrain.on_new_room_created(self)
	tilemap.erase_tiles()
	map.set_all_cells_to_room(self)

func finish_placement():
	# then fill the new room
	slope_painter.place_slopes(self)
	slope_painter.fill_room(self)

	outline.determine_outline()

# called when the NEXT room is being placed, as only then we know what should happen with this one
func finish_placement_in_hindsight():
	slope_painter.recalculate_room(self)
	items.determine_tiles_inside()
	
	lock.check_planned_lock()
	
	map.special_elements.add_special_items_to_room(self)
	map.edges.handle_gates(self)

func on_tutorial_placement():
	has_tutorial = true
	map.slope_painter.clear_room(self)
