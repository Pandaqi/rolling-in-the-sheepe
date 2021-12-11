extends Node

var outline = []
var has_border : bool = false

onready var rect = get_node("../Rect")
onready var route = get_node("../Route")

onready var map = get_node("/root/Main/Map")

func get_edges():
	return outline

func determine_outline():
	var arr = []
	
	# top and bottom cells
	var shrunk = rect.shrunk
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

func open_connection_to_previous_room():
	if not route.has_previous_room(): return
	if route.prev_room.lock.has_lock(): return

	for edge in outline:
		if not edge_links_to_previous_room(edge): continue

		map.edges.remove_at(edge.pos, edge.dir_index)

func create_border_around_us(params = {}):
	var type = "regular"
	if params.has('type'): type = params.type
	
	var prev_room = route.get_previous_room()
	for edge in outline:
		var other_side = edge_links_to(edge)
		if params.has('open_all_linked_edges'):
			if other_side and not (other_side == self): 
				map.edges.remove_at(edge.pos, edge.dir_index)
				continue
		elif prev_room:
			if other_side == prev_room and (not prev_room.lock.has_lock()):
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
	if not route.has_previous_room(): return false
	
	return (edge_links_to(edge) == route.get_previous_room())

func delete_edges_inside():
	var shrunk = rect.shrunk
	for x in range(shrunk.size.x):
		for y in range(shrunk.size.y):
			for i in range(4):
				var edge = { 'pos': shrunk.pos + Vector2(x,y), 'dir_index': i }
				var link = edge_links_to(edge)
				if not link or link != self: continue
				
				map.edges.remove_at(edge.pos, edge.dir_index)
