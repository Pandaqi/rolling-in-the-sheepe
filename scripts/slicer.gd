extends Node2D

const MAX_BODIES_PER_PLAYER : int = 5

const MIN_AREA_FOR_VALID_SHAPE : float = 150.0
const MIN_SIZE_PER_SIDE : float = 3.0 # TO DO: need to fix this anyway

onready var map = get_node("/root/Main/Map")
onready var player_manager = get_node("/root/Main/PlayerManager")
onready var player_progression = get_node("/root/Main/Map/PlayerProgression")
var body_scene = preload("res://scenes/body.tscn")

var start_point
var end_point

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

func slice_bodies_hitting_line(p1 : Vector2, p2 : Vector2, mask = []):
	var max_radius = max( abs(p1.x - p2.x), abs(p1.y - p2.y) )
	var angle = (p2 - p1).angle()
	var avg_pos = (p2 + p1)*0.5
	
	var shape = RectangleShape2D.new()
	shape.extents.x = 0.5*(p2-p1).length()
	shape.extents.y = 5
	
	var physics := get_world_2d().direct_space_state
	var query = Physics2DShapeQueryParameters.new()
	query.set_shape(shape)
	query.transform = Transform2D(angle, avg_pos)

	var results = physics.intersect_shape(query)
	var bodies = []
	for res in results:
		var body = res.collider
		
		if not (body is RigidBody2D): continue
		if not (body.has_node("Shaper")): continue
		if mask.size() > 0 and not (body in mask): continue
		
		if not body in bodies:
			bodies.append(body)

	for b in bodies:
		slice_body(b, p1, p2)

func create_basic_body(b, type, shrinker : float = 1.0):
	var base_pos = b.get_global_position()
	var radius = b.get_node("Shaper").approximate_radius_for_basic_body(shrinker)
	
	var num_points = GlobalDict.points_per_shape[type]
	
	var arr = []
	for a in range(num_points):
		var angle = (a / float(num_points)) * (2*PI)
		var new_pos = base_pos + Vector2(cos(angle), sin(angle))*radius
		arr.append(new_pos)
	
	return arr

func slice_body(b, p1, p2):
	var original_player_num = b.get_node("Status").player_num
	var original_coins = b.get_node("Coins").count()
	
	var player_is_at_body_limit = (player_manager.count_bodies_of_player(original_player_num) >= MAX_BODIES_PER_PLAYER)
	if player_is_at_body_limit: 
		print("Player already has too many bodies")
		return
	
	if GlobalDict.cfg.unrealistic_slicing:
		b.get_node("Status").delete()
		
		var new_type = GlobalDict.cfg.slicing_yields
		var new_shapes = []
		for i in range(2):
			new_shapes.append( create_basic_body(b, new_type, 0.5) )
		
		var coins_a = floor(original_coins * 0.5)
		var coins_b = original_coins - coins_a
		create_body_from_shape(new_shapes[0], { 'player_num': original_player_num, 'coins': coins_a, 'type': new_type })
		create_body_from_shape(new_shapes[1], { 'player_num': original_player_num, 'coins': coins_b, 'type': new_type })
		
		return
	
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
		print("Slicing didn't change anything")
		return
	
	# determine which shapes belong together ("are in the same layer")
	var shape_layers = determine_shape_layers(new_shapes, p1, p2)
	
	# now check if this slice will do something ugly we don't want
	# (body too small or too narrow, will glitch physics and look bad)
	var slice_too_small = false
	for key in shape_layers:
		if area_too_small(shape_layers[key]): 
			slice_too_small = true
			break

		if bounding_box_too_small(shape_layers[key]):
			slice_too_small = true
			break
	
	if slice_too_small:
		print("Slicing returned a body too small")
		return
	
	# destroy the old body
	b.get_node("Status").delete()
	
	# create bodies for each set of points left over
	var vec = (p2 - p1)
	var ortho_vec = vec.rotated(PI)

	var num_resulting_bodies = shape_layers.keys().size()
	var total_coins_distributed = 0
	for i in range(num_resulting_bodies):
		var shp = shape_layers[i]
		var coin_total = round(original_coins / float(num_resulting_bodies))
		
		var last_body_to_make = (i == (num_resulting_bodies - 1))
		if last_body_to_make:
			coin_total = original_coins - total_coins_distributed
		
		var body = create_body_from_shape_list(original_player_num, shp, coin_total)
		
		total_coins_distributed += coin_total
		body.plan_shoot_away(ortho_vec)

func determine_shape_layers(new_shapes, p1, p2):
	var saved_layers = []
	
	# initialize all to "no layer"
	for _i in range(new_shapes.size()):
		saved_layers.append(-1)
	
	# move through shapes left to right
	var cur_highest_layer = 0
	for i in range(new_shapes.size()):
		
		# not in a layer yet? create a new one, add us to it, and save the index
		# (the previous shapes never matched ours, so we can't be in the same layer)
		if saved_layers[i] == -1:
			saved_layers[i] = cur_highest_layer
			cur_highest_layer += 1
		
		# now check if we're adjacent to any other shapes
		var our_layer = saved_layers[i]
		for j in range(new_shapes.size()):
			if i == j: continue
			
			var their_layer = saved_layers[j]
			if their_layer == our_layer: continue
			
			if not is_adjacent(new_shapes[i], new_shapes[j], p1, p2): continue

			# they aren't in any group yet? put them in our group
			if their_layer == -1:
				saved_layers[j] = our_layer
				continue
			
			# they are part of an earlier group?
			# reduce us to that group and start checking again
			if their_layer < our_layer:
				saved_layers[i] = their_layer
				our_layer = their_layer
				j = -1 # start again from the front, because we need to take everyone else in our (previous) layer with us
	
	# now that each shape has a layer index,
	# simply build a dictionary from that
	var shape_layers = {}
	
	for i in range(new_shapes.size()):
		var shp = new_shapes[i]
		var layer = saved_layers[i]
		
		if not shape_layers.has(layer):
			shape_layers[layer] = []
		
		shape_layers[layer].append(shp)
	
	return shape_layers

func make_shape_global(owner, shape : ConvexPolygonShape2D) -> Array:
	var trans = owner.get_global_transform()
	
	var points = Array(shape.points) + []
	for j in range(points.size()):
		points[j] = trans.xform(points[j])
	
	return points

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
	
	if not succesful_slice: return [shp]
	
	shape1 = shp.slice(0,intersect_indices[0])
	shape1.append(intersect_points[0])
	shape1.append(intersect_points[1])
	shape1 += shp.slice(intersect_indices[1]+1,shp.size()-1)
	
	shape2 = shp.slice(intersect_indices[0]+1, intersect_indices[1])
	shape2.push_front(intersect_points[0])
	shape2.append(intersect_points[1])
	
	return [shape1, shape2]

func bounding_box_too_small(shapes):
	var x = { 'min': INF, 'max': -INF }
	var y = { 'min': INF, 'max': -INF }
	
	# try the default AND the shape rotated 45 degrees (which will always yield a BIGGER result)
	# to ensure we also catch thin slices that just happen to be rotated
	for shp in shapes:
		for p in shp:
			x.min = min(x.min, p.x)
			x.max = max(x.max, p.x)
			
			y.min = min(y.min, p.y)
			y.max = max(y.max, p.y)
	
	var size = Vector2(x.max - x.min, y.max - y.min)
	if size.x < MIN_SIZE_PER_SIDE or size.y < MIN_SIZE_PER_SIDE:
		return true
	
	return false

func area_too_small(shapes):
	var area = 0
	for shp in shapes:
		var extra_area = calculate_area_shoelace(shp)
		area += extra_area

	return (area < MIN_AREA_FOR_VALID_SHAPE)

func create_body_from_shape_list(player_num : int, shapes : Array, coins : int) -> RigidBody2D:
	var body = body_scene.instance()
	
	# the average centroid of all centroids will be the center of the new body
	var avg_pos = Vector2.ZERO
	for shp in shapes:
		avg_pos += calculate_centroid(shp)
	
	avg_pos /= float(shapes.size())
	body.position = avg_pos
	
	# now we ask the body to create a collision thing from our shapes
	body.get_node("Shaper").create_from_shape_list(shapes)
	
	map.add_child(body)
	
	# and we make sure it has the same parent as the original body
	body.get_node("Status").set_player_num(player_num)
	body.get_node("Coins").get_paid(coins)
	
	return body

func create_body_from_shape(shp : Array, params = {}) -> RigidBody2D:
	var body = body_scene.instance()
	
	body.position = calculate_centroid(shp)
	
	body.get_node("Shaper").create_from_shape(shp, params)
	
	map.add_child(body)
	
	# and we make sure it has the same parent as the original body
	body.get_node("Status").set_player_num(params.player_num)
	body.get_node("Coins").get_paid(params.coins)
	
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

func is_adjacent(sh1, sh2, slice_start, slice_end):
	var epsilon : float = 0.05
	
	for p1 in sh1:
		
		var along_slicing_line = point_is_between(slice_start, slice_end, p1)
		if along_slicing_line: continue
		
		for p2 in sh2:
			along_slicing_line = point_is_between(slice_start, slice_end, p2)
			if along_slicing_line: continue
			
			if (p1-p2).length() > epsilon: continue

			return true

func point_is_between(a, b, c):
	# CRUCIAL NOTE! 
	#  => If you take this too SMALL, this will perform erratically, ruining the algorithm
	#  => If too big, it will obviously slice more than it should
	#  => However, seeing that the crossproduct uses non-normalized vectors, and distances can be huge, I think you're quite safe with epsilons > 0.1
	var epsilon = 0.1
	
	var crossproduct = (c.y - a.y) * (b.x - a.x) - (c.x - a.x) * (b.y - a.y)
	if abs(crossproduct) > epsilon: return false
	
	var dotproduct = (c.x - a.x) * (b.x - a.x) + (c.y - a.y)*(b.y - a.y)
	if dotproduct < 0: return false
	
	var squaredlengthba = (b - a).length_squared()
	if dotproduct > squaredlengthba:
		return false
	
	return true

func calculate_area_shoelace(shp):
	var area = 0
	
	for i in range(shp.size()):
		var next_index = (i+1) % int(shp.size())
		var p1 = shp[i]
		var p2 = shp[next_index]
		
		area += p1.x * p2.y - p1.y * p2.x
	
	return area * 0.5

func calculate_area(shp):
	var x_bounds = Vector2(INF, -INF)
	var y_bounds = Vector2(INF, -INF)
	
	for point in shp:
		x_bounds.x = min(point.x, x_bounds.x)
		x_bounds.y = max(point.x, x_bounds.y)
		
		y_bounds.x = min(point.y, y_bounds.x)
		y_bounds.y = max(point.y, y_bounds.y)
	
	var width = (x_bounds.y - x_bounds.x)
	var height = (y_bounds.y - y_bounds.x)
	
	return 0.5*width*height
	
	
	
