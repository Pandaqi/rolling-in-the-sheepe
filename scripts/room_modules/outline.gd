extends Node

var outline = []
var has_border : bool = false

onready var parent = get_parent()

func get_edges():
	return outline

func determine_outline():
	var arr = []
	
	# top and bottom cells
	var shrunk = parent.rect.shrunk
	var p = shrunk.pos
	for x in range(shrunk.size.x):
		arr.append({ 'pos': p + Vector2(x,0), 'dir_index': 3 })
		arr.append({ 'pos': p + Vector2(x,shrunk.size.y-1), 'dir_index': 1 })
	
	# left and right cells
	for y in range(shrunk.size.y):
		arr.append({ 'pos': p + Vector2(shrunk.size.x-1,y), 'dir_index': 0 })
		arr.append({ 'pos': p + Vector2(0,y), 'dir_index': 2 })
	
	outline = arr
	
	# DEBUGGING
	#delete_edges_inside()
	
	open_connection_to_previous_room()

func recalculate_outline():
	open_connection_to_previous_room()

func open_connection_to_previous_room():
	if not parent.route.has_previous_room(): return
	if parent.route.prev_room.lock.has_lock(): return

	for edge in outline:
		if not edge_links_to_previous_room(edge): continue

		parent.map.edges.remove_at(edge.pos, edge.dir_index, true)

func seal():
	create_border_around_us({ 'close_all': true })

func create_border_around_us(params = {}):
	var type = "regular"
	if params.has('type'): type = params.type
	
	for edge in outline:
		parent.map.edges.set_at(edge.pos, edge.dir_index, type)
	
	var prev_room = parent.route.get_previous_room()
	for edge in outline:
		if params.has('close_all'): continue
		
		var other_side = edge_links_to(edge)
		var same_room_but_open = edge_links_to_same_room_but_open(edge)
		
		# if we don't do this, the actual gates/locks are ALSO opened on same-room-but-open sides
		var is_back_edge = (edge.dir_index != parent.route.dir)
		
		if prev_room and prev_room.lock.has_lock(): continue
		
		if params.has('open_all_linked_edges'):
			if other_side and not (other_side == self):
				parent.map.edges.remove_at(edge.pos, edge.dir_index, true)
		elif prev_room:
			if other_side == prev_room or (same_room_but_open and is_back_edge):
				parent.map.edges.remove_at(edge.pos, edge.dir_index, true) 
	
	has_border = true

func remove_border_around_us():
	for edge in outline:
		parent.map.edges.remove_at(edge.pos, edge.dir_index)

func turn_border_into_soft_border():
	for edge in outline:
		var soft_remove = true
		var other_side = edge_links_to(edge)
		var they_are_later = other_side and (other_side.route.index > parent.route.index)
		var same_room_but_open = edge_links_to_same_room_but_open(edge)
		
		if (other_side and they_are_later) or same_room_but_open:
			soft_remove = false
		
		parent.map.edges.remove_at(edge.pos, edge.dir_index, soft_remove)

func edge_links_to(edge):
	var opposite_grid_pos = edge.pos + parent.map.get_vector_from_dir(edge.dir_index)
	if parent.map.out_of_bounds(opposite_grid_pos): return null
	
	return parent.map.get_cell(opposite_grid_pos).room

func edge_links_to_same_room_but_open(edge):
	var other_side = edge_links_to(edge)
	if not other_side: return
	
	var other_pos = edge.pos + parent.map.get_vector_from_dir(edge.dir_index)
	var same_room = (other_side.route.index == parent.route.index)
	var is_open = parent.map.slope_painter.tile_is_half_open(other_pos)
	
	return same_room and is_open

func edge_links_to_previous_room(edge):
	if not parent.route.has_previous_room(): return false
	
	return (edge_links_to(edge) == parent.route.get_previous_room())

func delete_edges_inside():
	for temp_pos in parent.rect.shrunk_positions:
		for i in range(4):
			var edge = { 'pos': temp_pos, 'dir_index': i }
			var link = edge_links_to(edge)
			if not link or link != self: continue
			
			parent.map.edges.remove_at(edge.pos, edge.dir_index)
