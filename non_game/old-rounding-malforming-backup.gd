##
## Deforming
##  => These functions are basically useless now, as I don't think I'll ever activate this system again ...
##
#
## TO DO: Ensure minimum dimensions here as well
## (Maybe just require all points to be some distance away from Vector2.ZERO?)
#
## TO DO: This doesn't even work, as points that are _overlapping_ ( = matching) wiill get sent in different directions ... unless I _seed_ the randomness based on rounded coordinates?
#func become_more_malformed():
#	print("MALFORM!")
#
#	if body.status.is_wolf: return
#
#	var ratio = average_airtime
#	if grow_instead_of_rounding:
#		shrink(GROW_FACTOR*ratio)
#		return
#	if body.shaper.is_fully_malformed(): return
#
#	var num_shapes = body.shape_owner_get_shape_count(0)
#	for i in range(num_shapes):
#		var shape = body.shape_owner_get_shape(0, i)
#		shape.points = move_points_randomly(shape.points)
#
#	body.shaper.reposition_all_around_centroid()
#	body.shaper.on_shape_updated()
#
#func move_points_randomly(shp):
#	for i in range(shp.size()):
#		shp[i] += Vector2(randf(), randf())
#
#	return shp
#
##
## Rounding
##
#func become_more_round():
#	if body.status.is_wolf: return
#
#	var ratio = 1.0 - average_airtime
#	if grow_instead_of_rounding:
#		grow(GROW_FACTOR*ratio)
#		return
#	if body.shaper.is_fully_round(): return
#
#	var num_shapes = body.shape_owner_get_shape_count(0)
#	var shapes_to_add = []
#
#	var total_number_of_points : int = 0
#	for i in range(num_shapes):
#		var shape = body.shape_owner_get_shape(0, i)
#		total_number_of_points += shape.points.size()
#
#	var should_enrich_shape = (total_number_of_points / float(num_shapes)) <= 5
#
#	var avg_pos : Vector2 = Vector2.ZERO
#	var total_points_considered : int = 0
#
#	for i in range(num_shapes):
#		var shape = body.shape_owner_get_shape(0, i)
#		var pts = Array(shape.points)
#
#		if should_enrich_shape:
#			pts = enrich_shape(pts)
#
#		var new_points = move_points_to_circle(pts, ratio)
#
#		for p in new_points:
#			avg_pos += p
#			total_points_considered += 1
#
#		shapes_to_add.append(new_points)
#
#	# reposition all points around centroid
#	var offset = avg_pos/float(total_points_considered)
#	for shp in shapes_to_add:
#		for i in range(shp.size()):
#			shp[i] = (shp[i] - offset).rotated(-body.rotation)
#
#	for shp in shapes_to_add:
#		var new_shape = ConvexPolygonShape2D.new()
#		new_shape.points = shp
#		body.shape_owner_remove_shape(0, 0)
#		body.shape_owner_add_shape(0, new_shape)
#
#	body.shaper.on_shape_updated()
#
#func move_points_to_circle(shp, ratio):
#	var c = body.get_global_position()
#	var radius = body.shaper.approximate_radius() + RADIUS_INCREASE_FOR_ROUNDING
#
#	var total_movement = 0
#
#	shp = body.shaper.make_global(shp)
#	for i in range(shp.size()):
#		var p = shp[i] - c
#		var ang = snap_angle(p.angle())
#		var circle_pos = Vector2(cos(ang), sin(ang))*radius
#
#		var new_pos = p.linear_interpolate(circle_pos, 0.5*ratio)
#		shp[i] = new_pos
#
#		total_movement += (new_pos - p).length()
#
#	if total_movement < MOVEMENT_THRESHOLD_BEFORE_ROUND:
#		pass # just make it a perfect circle
#
#	return shp
#
#func snap_angle(ang):
#	var num_points : float = 16.0
#
#	return round(ang / (2.0*PI) * num_points) * (2.0*PI) / num_points
#
#func enrich_shape(shp):
#	print(shp)
#
#	var i = 0
#	while i < shp.size():
#		var next_i = (i + 1) % int(shp.size())
#		var p1 = shp[i]
#		var p2 = shp[next_i]
#
#		var half_point = 0.5 * (p1 + p2)
#
#		shp.insert(i+1, half_point)
#		i += 2 # skip the point we just inserted
#
#	return shp
