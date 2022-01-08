extends Node

var outline = []
var type : String = ""
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
		arr.append({ 'pos': p + Vector2(x,0), 'dir_index': 3, 'gate': false })
		arr.append({ 'pos': p + Vector2(x,shrunk.size.y-1), 'dir_index': 1, 'gate': false })
	
	# left and right cells
	for y in range(shrunk.size.y):
		arr.append({ 'pos': p + Vector2(shrunk.size.x-1,y), 'dir_index': 0, 'gate': false })
		arr.append({ 'pos': p + Vector2(0,y), 'dir_index': 2, 'gate': false })
	
	outline = arr

func determine_connections():
	var doesnt_need_border = not parent.lock.has_lock()
	if doesnt_need_border: return
	
	var type = parent.lock.edge_type
	has_border = true
	
	# close everything
	for edge in outline:
		edge.gate = false
		parent.map.edges.set_at(edge.pos, edge.dir_index, type)
	
	# then open what we want
	for edge in outline:
		# previous room? soft-remove the edge
		if edge_links_to_previous_room(edge):
			parent.map.edges.remove_at(edge.pos, edge.dir_index, true)
		
		# next room? turn them into gates
		elif edge_links_to_next_room(edge):
			edge.gate = true
		
		# anything else? just keep it, don't open
	
	# check if connections to next room need to be turned into _gates_
	if GDict.edge_types[type].has("gate"): 
		for edge in outline:
			if not edge.gate: continue
			
			var edge_body = parent.map.edges.set_at(edge.pos, edge.dir_index, type)
			edge_body.link_to_room({ 'room': parent, 'gate': true })

func edge_links_to_previous_room(edge):
	var cell = edge_links_to_cell(edge)
	if not cell: return false
	
	var our_index = parent.route.index
	
	var is_open = other_side_is_open(edge)
	var is_earlier_room : bool = false
	if cell.room and cell.room.route.index < our_index: 
		is_earlier_room = true
	
	if cell.old_room and cell.old_room.route.index < our_index:
		is_earlier_room = true
	
	return is_earlier_room and is_open

func edge_links_to_next_room(edge):
	var cell = edge_links_to_cell(edge)
	if not cell: return false
	
	return (cell.room.route.index > parent.route.index) and other_side_is_open(edge)

func other_side_is_open(edge):
	var other_pos = edge.pos + parent.map.get_vector_from_dir(edge.dir_index)
	var is_open = parent.map.slope_painter.tile_is_half_open(other_pos)
	return is_open or not parent.tilemap.is_cell_filled(other_pos)

func remove_border_around_us():
	for edge in outline:
		parent.map.edges.remove_at(edge.pos, edge.dir_index)

func turn_border_into_soft_border():
	for edge in outline:
		var soft_remove = true
		if edge.gate: soft_remove = false

		parent.map.edges.remove_at(edge.pos, edge.dir_index, soft_remove)

func edge_links_to_cell(edge):
	var opposite_grid_pos = edge.pos + parent.map.get_vector_from_dir(edge.dir_index)
	if parent.map.out_of_bounds(opposite_grid_pos): return null
	
	return parent.map.get_cell(opposite_grid_pos)
