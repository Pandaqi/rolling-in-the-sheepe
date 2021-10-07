extends Node2D

onready var main_node = get_node("/root/Main")
var body_scene = preload("res://scenes/body.tscn")

var start_point
var end_point

onready var test_body = get_node("/root/Main/Body")

func _input(ev):
	if ev is InputEventMouseMotion:
		update()
	
	if (ev is InputEventMouseButton):
		if ev.pressed:
			start_point = get_global_mouse_position()
			end_point = null
		else:
			end_point = get_global_mouse_position()
			slice_bodies_hitting_line(start_point, end_point)

func _draw():
	if not start_point: return
	
	var a = start_point
	var b = get_global_mouse_position()
	if end_point: b = end_point
	
	draw_line(a, b, Color(0,0,0), 2)

func slice_bodies_hitting_line(p1 : Vector2, p2 : Vector2):
	var max_radius = max( abs(p1.x - p2.x), abs(p1.y - p2.y) )
	var avg_pos = (p2 + p1)*0.5
	
	var shape = CircleShape2D.new()
	shape.radius = max_radius
	
	var physics := get_world_2d().direct_space_state
	var query = Physics2DShapeQueryParameters.new()
	query.set_shape(shape)
	
	query.transform = Transform2D(0, avg_pos)

	var results = physics.intersect_shape(query)
	var bodies = []
	for res in results:
		var body = res.collider
		
		if not (body is RigidBody2D): continue
		if not (body.has_node("Shaper")): continue
		
		if not body in bodies:
			bodies.append(body)
	
	for b in bodies:
		slice_body(b, p1, p2)

func slice_body(b, p1, p2):
	var num_shapes = b.shape_owner_get_shape_count(0)
	var cur_shapes = []
	var new_shapes = []
	
	# get the shapes inside this body as an array of GLOBAL point sets
	for i in range(num_shapes):
		var shape = b.shape_owner_get_shape(0, i)
		var points = make_shape_global(b, shape)

		cur_shapes.append(points)
	
	# slice these shapes individually
	for shp in cur_shapes:
		var res = slice_shape(shp, p1, p2)
		new_shapes += res
	
	# shape lists are the same? nothing happened, abort mission
	if cur_shapes.size() == new_shapes.size():
		return
	
	# destroy the old body
	b.queue_free()
	
	# THE IDEA
	# Create an object: "shape layers"
	# For each triangle, check if it has matching points with other triangles
	#  => If we find something, immediately put our shape into the SAME category as the one we matched
	#  => If we find nothing, create a new category for us, and put us in there
	# We should end up with 1+ lists of shapes that "belong together". Create a body for each list, then handing the shapes directly to it.
	var shape_layers = []
	var saved_layers = []
	
	
	# merge the new triangles
	# TO DO: THis is all a bit wonky and I'm not sure if this is the way to go
	var merge_triangles = true

	if merge_triangles:
		for i in range(0, new_shapes.size()):
			var tr1 = new_shapes[i]
		
			for j in range(i+1, new_shapes.size()):
				var tr2 = new_shapes[j]
					
				var res = try_merge(tr1, tr2)
				if res.size() == 2: continue
					
				new_shapes[i] = res[0]
				tr1 = res[0]
	
	# create bodies for each set of points left over
	for shp in new_shapes:
		create_body_from_shape(shp)

func try_merge(tr1, tr2):
	var epsilon : float = 0.003
	
	var start1 = -1
	var start2 = -1
	
	var sequence_length = -1
	
	# TO DO: ISSUE => this might not be the first point _in sequence_
	#        We, somehow, need to check at which point the LONGEST sequence starts
	# find the first matching point
	for a in range(tr1.size()):
		var p1 = tr1[a]
		for b in range(tr2.size()):
			var p2 = tr2[b]
			if (p1-p2).length() > epsilon: continue
			
			start1 = a
			start2 = b
			sequence_length = 1
			break
	
	# no match? abort mission
	if sequence_length < 0:
		return [tr1, tr2]
	
	# now check for how long we keep matching
	var found_match = true
	var pos1 = start1
	var pos2 = start2
	
	while found_match:
		found_match = false
		
		pos1 = (pos1 + 1) % int(tr1.size())
		pos2 = (pos2 - 1 + tr2.size()) % int(tr2.size())
		
		if (pos1-pos2).length() > epsilon: break
		
		found_match = true
		sequence_length += 1
	
	# no proper match? abort mission
	if sequence_length <= 1:
		return [tr1, tr2]
	
	# all UNMATCHED points need to be added to the original one
	# to merge the two triangles
	var points_to_add = tr2.size() - sequence_length
	for i in range(points_to_add):
		start2 = (start2 + 1) % int(tr2.size())
		
		var pos = tr2[start2]
		
		tr1.insert(start1, pos)
		start1 += 1
	
	return [tr1]

func make_shape_global(owner, shape : ConvexPolygonShape2D) -> Array:
	var trans = owner.get_global_transform()
	
	var points = Array(shape.points) + []
	for j in range(points.size()):
		points[j] = trans.xform(points[j])
	
	return points

#func make_shape_global(b, shape):
#	for i in range(shape.size()):
#		shape[i] = b.get_global_position() + shape[i].rotated(b.get_rotation())

func slice_shape(shp, slice_start : Vector2, slice_end : Vector2) -> Array:
	shp = shp + []

	var intersect_indices = []
	var intersect_points = []
	
	var shape1
	var shape2
	
	var succesful_slice : bool = false
	
	for i in range(shp.size()):
		var p1 : Vector2 = shp[i]
		var p2 : Vector2 = shp[(i+1) % int(shp.size())]
		
		var intersect_point = find_intersection_point(p1,p2,slice_start,slice_end)
		if not intersect_point: continue
		
		intersect_indices.append(i)
		intersect_points.append(intersect_point)
		
		if intersect_indices.size() >= 2:
			succesful_slice = true
			break
	
	if not succesful_slice: 
		print("Nothing to slice!")
		return [shp]
	
	shape1 = shp.slice(0,intersect_indices[0])
	shape1.append(intersect_points[0])
	shape1.append(intersect_points[1])
	shape1 += shp.slice(intersect_indices[1]+1,shp.size()-1)
	
	shape2 = shp.slice(intersect_indices[0]+1, intersect_indices[1])
	shape2.push_front(intersect_points[0])
	shape2.append(intersect_points[1])
	
	return [shape1, shape2]
	
	#var b1 = create_body_from_shape(shape1)
	#var b2 = create_body_from_shape(shape2)

func create_body_from_shape(shp : Array) -> RigidBody2D:
	var body = body_scene.instance()
	
	body.position = calculate_centroid(shp)
	
	# NOTE: the shape is currently GLOBAL, but because the shaper module already repositions it around Vector2.ZERO ( = -centroid), it automatically makes it LOCAL
	body.get_node("Shaper").shape = shp
	main_node.call_deferred("add_child", body)
	
	return body

###
#
# Helper functions
#
###
func find_intersection_point(a1 : Vector2, a2 : Vector2, b1 : Vector2, b2 : Vector2):
	# 1) Rewrite vectors as "p + t r" and "q + u s" (0 <= t,u <= 1)
	var p = a1
	var r = (a2-a1)
	
	var q = b1
	var s = (b2-b1)
	
	# 2) Check if they are collinear OR parallel (non-intersecting)
	# (We can calculate intersection point, but for simplicity we just ignore both cases)
	var qminp = (q - p)
	var rxs = (r.cross(s))
	if rxs == 0:
		return null
	
	# 3) calculate "t" and "u" (supposing lines are endless and they will intersect)
	# (We already determined rxs to not be 0, so this will not fail)
	var t = qminp.cross(s) / rxs
	var u = qminp.cross(r) / rxs
	
	# NOTE: we add some leeway here to disallow extremely tiny shapes
	var epsilon = 0.0
	
	if (t >= epsilon and t <= 1.0-epsilon) and (u >= epsilon and u <= 1.0-epsilon):
		return p + t*r

func calculate_centroid(shp):
	var avg = Vector2.ZERO
	for point in shp:
		avg += point
	
	return avg / float(shp.size())
