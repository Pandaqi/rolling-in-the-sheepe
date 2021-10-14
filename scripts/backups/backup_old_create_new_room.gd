


func generate_possible_rooms_in_dir(params, dir_index):
	var dirs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	
	var dir = dirs[dir_index]
	
	var back_room = (dir_index == 2 or dir_index == 3)
	var ortho_dir = Vector2(0,1)
	if dir_index == 1 or dir_index == 3:
		ortho_dir = Vector2(1,0)
	
	var max_size = Vector2(5,5)
	var rooms = []
	for x in range(1, max_size.x+1):
		for y in range(1, max_size.y+1):
			var new_size = Vector2(x,y)
			var displacement_bounds = get_displacement_bounds(params.room.size, new_size, dir_index)
			
			for a in range(displacement_bounds.min, displacement_bounds.max+1):
				var pos = params.base_pos + dir * params.room.size + ortho_dir*a
				
				if back_room:
					pos = params.base_pos + dir * new_size + ortho_dir*a
				
				rooms.append({ 'pos': pos, 'size': new_size  })
	
	return rooms

func can_place_rectangle(r, ignore_room_index, growth_area : int = 0):
	for x in range(r.size.x):
		for y in range(r.size.y):
			var my_pos = r.pos + Vector2(x,y)
			
			# if the rectangle was GROWN, the REAL rectangle might still be inside the bounds, so ignore if the pos is inside this buffer
			if map.dist_to_bounds(my_pos) > growth_area: 
				return false
			
			for i in range(cur_path.size()):
				if i == ignore_room_index: continue
				if r.overlaps(cur_path[i]): return false
	
	return true

func find_valid_configuration(params):
	# Keep trying to find an open spot
	# changing room SIZE and DISPLACEMENT ( = exact position) every time
	var final_candidate
	
	var num_tries = 0
	var smaller_room_try_threshold = 150
	var check_against_grown_rect_threshold = 150
	var forced_dir_try_threshold = 190 #NOTE: Must be HIGHER than the others, otherwise it's very hard to do a zigzag and go back early (just too little space)
	var max_tries = 200
	
	var base_pos = params.room.pos
	var bad_choice = true

	var rect = params.rect
	
	params.disallow_going_back = true
	params.overlapping_rooms_were_allowed = false
	params.disallow_long_verticals = true
	
	var forced_dir_exists = (params.forced_dir >= 0)
	
	if tutorial.wanted_tutorial_placement:
		params.require_large_size = true
	
	while bad_choice and num_tries < max_tries:
		bad_choice = false
		
		rect.set_random_size(params.require_large_size)
		
		if forced_dir_exists and tutorial.is_active():
			rect.set_size(default_room_size_for_tutorial)
		
		# when we're out of space (mostly)
		# try 1-wide, very long rooms for a while
		# (they'll most likely fit AND get us out of trouble)
		if num_tries > smaller_room_try_threshold:
			var ratio = 1.0 - (num_tries - smaller_room_try_threshold) / float(max_tries - smaller_room_try_threshold)
			var long_side = round( max(5 * ratio, 1) )
			
			rect.set_size(Vector2(1,long_side))
			if randf() <= 0.5:
				rect.set_size(Vector2(long_side,1))
			
			params.disallow_going_back = false
			params.ignore_optional_requirements = true
			params.require_large_size = false

		var dirs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
		
		var candidates = []
		
		var last_dir = params.room.dir
		var opposite_to_last_dir = ((last_dir + 2) % 4)
		
		for i in range(dirs.size()):
			if params.disallow_going_back:
				if i == opposite_to_last_dir: 
					continue
			
			if params.disallow_long_verticals:
				if last_dir == 1 or last_dir == 3:
					if i == 1 or i == 3:
						continue
			
			var random_displacement = get_random_displacement(params.room, rect, i)

			var dir = dirs[i]
			var temp_pos = base_pos + dir * params.room.size + random_displacement
			
			if dir.x < 0 or dir.y < 0:
				temp_pos = base_pos + dir * rect.size + random_displacement
			
			rect.set_pos(temp_pos)
			
			var rect_to_check_against = rect
			var ignore_index = -1
			var growth_val = 0
			if num_tries < check_against_grown_rect_threshold:
				rect_to_check_against = rect.copy_and_grow(1)
				ignore_index = params.room.index
				growth_val = 1
			else:
				# NOTE: if we don't grow the rectangle, we should NOT ignore
				#  with ANY room, as that means an ACTUAL OVERLAP
				params.overlapping_rooms_were_allowed = true
			
			if not route_generator.can_place_rectangle(rect_to_check_against, ignore_index, growth_val): 
				continue
			
			# make horizontal movements more probable
			var weight : int = 1
			if i == 0 or i == 2:
				weight = 3
			
			for _w in range(weight):
				candidates.append({ 'dir': dir, 'pos': temp_pos, 'dir_index': i })
		
		if candidates.size() <= 0:
			bad_choice = true
			num_tries += 1
			continue
		
		final_candidate = candidates[randi() % candidates.size()]
		
		# if a forced direction was specified
		# search for a candidate that matches and pick that one
		var able_to_match_forced_dir = false
		if forced_dir_exists:
			for c in candidates:
				if c.dir_index == params.forced_dir:
					final_candidate = c
					able_to_match_forced_dir = true
					tutorial.record_forced_dir_match()
					break
			
		if forced_dir_exists and not able_to_match_forced_dir:
			if num_tries < forced_dir_try_threshold:
				bad_choice = true
				num_tries += 1
				continue
			else:
				tutorial.forced_dir_exhausted()
		
		params.dir = final_candidate.dir_index
		
		rect.set_pos(final_candidate.pos)
	
	params.no_valid_placement = (num_tries >= max_tries)
