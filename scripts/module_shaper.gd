extends Node2D

# when changing bodies, we "lose" some of our area, so this compensates
# NOTE: it's certainly NOT perfect, as it depends on whether you grow/shrink, and which shape exactly you move to, but it's a middle ground
const BASIC_BODY_RADIUS_GROWTH : float = 1.25

const MIN_RADIUS : float = 14.0
const MAX_RADIUS : float = 26.0 # JUST fits between gaps
const SIZE : float = 20.0

var area : float
var circumcircle_radius : float
var avg_angle : float
var bounding_box

var shape_type : String = ""
var starting_shape : String = ""

onready var body = get_parent()

func set_starting_shape(shape_key : String):
	starting_shape = shape_key

func is_fully_round():
	return (shape_type == "circle")

func is_fully_malformed():
	return (shape_type == "triangle")

#####
#
# Creation (from given shape/parameters
#
#####
func destroy():
	var num_shapes = body.shape_owner_get_shape_count(0)
	for _i in range(num_shapes):
		body.shape_owner_remove_shape(0, 0)

func create_new_from_shape_key(key : String):
	var already_this_shape = (key == shape_type)
	if already_this_shape: return
	
	GAudio.play_dynamic_sound(body, "plop_multiple")
	create_new_from_shape(GDict.shape_list[key].points, { 'type': key })

func create_new_from_shape(shp, params):
	destroy()
	create_from_shape(shp, params)

func append_shape(shape):
	var shape_node = ConvexPolygonShape2D.new()
	shape_node.points = shape
	body.shape_owner_add_shape(0, shape_node)
	
	on_shape_updated()

func create_from_shape_list(shapes):
	for i in range(shapes.size()):
		var shp = make_local(shapes[i])
		var shape_node = ConvexPolygonShape2D.new()
		shape_node.points = shp
		get_parent().shape_owner_add_shape(0, shape_node)

	on_shape_updated()

func create_from_shape(shp, params):
	var shape = reposition_around_centroid(shp)
	
	var col_node = get_parent().get_node("CollisionPolygon2D")
	col_node.polygon = shape
	
	shape_type = params.type
	
	on_shape_updated()

func create_from_random_shape():
	create_from_shape(create_random_shape(), { 'type': 'random' })

func create_random_shape():
	var shape = []
	
	var ang = 0
	var avg_ang_jump = 0.2*PI
	var ang_jump_error = 0.5
	
	var avg_radius = SIZE
	var avg_radius_error = 0.5
	
	while ang < 2*PI:
		var radius = (1.0 + (randf() - 0.5)*avg_radius_error)*avg_radius
		var p = Vector2(cos(ang), sin(ang))*radius
		
		shape.append(p)
		
		ang += (1.0 + (randf()-0.5)*ang_jump_error)*avg_ang_jump
	
	return shape

func reset_to_starting_shape():
	GAudio.play_dynamic_sound(body, "plop_multiple")
	create_new_from_shape_key(starting_shape)

#####
#
# Helpers
#
#####
func make_point_global(point):
	return get_parent().get_global_transform().xform(point)

func make_local(shp):
	shp = shp + []
	
	# The comment below does NOT work because the parent hasn't been added to scene tree yet
	# It's also not necessary, as we start a new, so only position is important (not rotation)
	#var trans = get_parent().get_global_transform()
	# shp[i] = trans.xform_inv(shp[i])
	
	for i in range(shp.size()):
		shp[i] -= get_parent().position
	
	return shp

func make_local_external(shp):
	shp = shp + []
	
	var trans = get_parent().get_global_transform()
	for i in range(shp.size()):
		shp[i] = trans.xform_inv(shp[i])
	
	return shp

func make_global(shp):
	shp = shp + []
	
	var trans = get_parent().get_global_transform()
	for i in range(shp.size()):
		shp[i] = trans.xform(shp[i])
	
	return shp

func reposition_around_centroid(shp, given_centroid = null):
	var centroid
	if given_centroid:
		centroid = given_centroid
	else:
		centroid = calculate_centroid(shp)
	
	for i in range(shp.size()):
		shp[i] -= centroid
	
	return shp

func calculate_centroid(shp):
	var avg = Vector2.ZERO
	for point in shp:
		avg += point
	
	return avg / float(shp.size())

#####
#
# Updating
#
#####
func on_shape_updated():
	body = get_parent()
	
	body.get_node("Drawer").update_shape()
	recalculate_bounding_box() 
	recalculate_area()
	body.get_node("Face").update_size(bounding_box)

#####
#
# Bounding box management (area, radius, etc.)
#
#####
func recalculate_bounding_box():
	var bounds = {
		'x': { 'min': INF, 'max': -INF},
		'y': { 'min': INF, 'max': -INF}
	}
	
	var col_node = get_parent()
	for i in range(col_node.shape_owner_get_shape_count(0)):
		var shp = col_node.shape_owner_get_shape(0, i)
		
		for point in shp.points:
			#var p = make_point_global(point)
			var p = point
			
			bounds.x.min = min(bounds.x.min, p.x)
			bounds.x.max = max(bounds.x.max, p.x)
			
			bounds.y.min = min(bounds.y.min, p.y)
			bounds.y.max = max(bounds.y.max, p.y)
	
	bounding_box = bounds

func get_area():
	return area

func recalculate_area():
	area = 0
	circumcircle_radius = 0
	avg_angle = 0
	
	var num_shapes = body.shape_owner_get_shape_count(0)
	for i in range(num_shapes):
		var shape = body.shape_owner_get_shape(0, i)
		var pts = shape.points
		
		area += calculate_shape_area_shoelace(pts)
		circumcircle_radius = max(circumcircle_radius, calculate_circumcircle(pts))
		avg_angle += calculate_avg_angle(pts)
	
	avg_angle /= float(num_shapes)

func get_avg_angle():
	return avg_angle

func calculate_avg_angle(shp):
	var ang = 0
	for i in range(shp.size()):
		var next_index = (i+1) % int(shp.size())
		var p1 = shp[i]
		var p2 = shp[next_index]
		
		ang = (p2 - p1).angle()
	
	return ang / float(shp.size())

func calculate_shape_area_shoelace(shp):
	var A = 0
	
	for i in range(shp.size()):
		var next_index = (i+1) % int(shp.size())
		var p1 = shp[i]
		var p2 = shp[next_index]
		
		A += p1.x * p2.y - p1.y * p2.x
	
	return abs(A * 0.5)

#func approximate_radius():
#	var x_length = abs(bounding_box.x.min) + abs(bounding_box.x.max)
#	var y_length = abs(bounding_box.y.min) + abs(bounding_box.y.max)
#	var approx =  0.5 * (Vector2(x_length, 0) - Vector2(0, y_length)).length()
#
#	return clamp(approx, MIN_RADIUS, MAX_RADIUS)

func get_circumcircle_radius():
	return circumcircle_radius

func calculate_circumcircle(shp):
	var c = 0
	for i in range(shp.size()):
		c = max(c, shp[i].length())
	return c

func approximate_radius():
	return sqrt(area / PI)

func approximate_radius_as_ratio():
	return approximate_radius() / float(MAX_RADIUS)

func approximate_radius_for_basic_body(shrinker : float = 1.0):
	var radius = shrinker*BASIC_BODY_RADIUS_GROWTH * approximate_radius()
	return clamp(radius, MIN_RADIUS, MAX_RADIUS)

func at_max_size():
	return approximate_radius() >= MAX_RADIUS

func at_min_size():
	return approximate_radius() <= MIN_RADIUS

func get_bounding_box_along_vec(vec):
	# convert bounding box to vectors (from centroid)
	var bounding_box_vectors = [
		{ 'vec': Vector2.RIGHT, 'dist': bounding_box.x.max}, 
		{ 'vec': Vector2.DOWN, 'dist': bounding_box.y.max}, 
		{ 'vec': Vector2.LEFT, 'dist': bounding_box.x.min},
		{ 'vec': Vector2.UP, 'dist': bounding_box.y.min}
	]
	
	# rotate them to match our current ROTATION
	# (so they are, you know, actually correct)
	var rot = get_parent().rotation
	for obj in bounding_box_vectors:
		obj.vec = obj.vec.rotated(rot)
	
	# then check which one MOST CLOSELY aligns with the given vec
	var best_option = null
	var best_dot = -INF
	
	for obj in bounding_box_vectors:
		var dot_prod = vec.dot(obj.vec)
		
		if dot_prod > best_dot:
			best_option = abs(obj.dist)
			best_dot = dot_prod
		
		if dot_prod >= 0.5:
			return abs(obj.dist)
	
	# if nothing matches, which can happen sporadically, just return the best one of all options
	return best_option
