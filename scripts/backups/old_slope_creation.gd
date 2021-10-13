####
#
# Managing the tilemap
# (making it look pretty, adding slopes, making sure we choose the right tiles, etc.)
#
####

# TO DO: Shouldn't these be functions on the RECTANGLES themselves? Or at least partly?
func should_be_slope(pos):
	# a cell with precisely two neighbours ...
	var nbs = get_neighbor_tiles(pos, { 'filled': true })
	if nbs.size() != 2: return false
	
	# who are at an angle ( = NOT opposite each other) ...
	var epsilon = 0.05
	if (nbs[0] - pos).dot(nbs[1] - pos) < -(1 - epsilon): return false
	
	# slope!
	return true

func is_slope(pos):
	return tilemap.get_cellv(pos) == 1

func check_for_slopes(r):
	var slopes_to_create = []
	
	# remove slopes that have become nonsensical
	for x in range(r.size.x):
		for y in range(r.size.y):
			var pos = r.pos + Vector2(x,y)

			if is_slope(pos) and not should_be_slope(pos):
				change_cell(pos, -1)
	
	# plan the creation of new slopes
	for x in range(r.size.x):
		for y in range(r.size.y):
			var pos = r.pos + Vector2(x,y)
			if not should_be_slope(pos): continue
			
			var nbs = get_neighbor_tiles(pos, { 'filled': true })
			slopes_to_create.append({ 'pos': pos, 'nbs': nbs })
	
	# actually create the slopes AND rotate them correctly
	for s in slopes_to_create:
		var pos = s.pos
		var nbs = s.nbs
		
		var flip_x = false
		if (pos - nbs[0]).x > 0 or (pos - nbs[1]).x > 0: flip_x = true 
		
		var flip_y = false
		if (pos - nbs[0]).y > 0 or (pos - nbs[1]).y > 0: flip_y = true
		
		# @params => set_cellv (pos, id, flip_x, flip_y, transpose)
		change_cell(pos, 1, flip_x, flip_y)
