extends Node2D

const SIZE : float = 20.0

var bounding_box

#####
#
# Creation (from given shape/parameters
#
#####
func create_from_shape_list(shapes):
	var col_node = get_parent().get_node("CollisionPolygon2D")
	
	for i in range(shapes.size()):
		var shp = make_local(shapes[i])
		var shape_node = ConvexPolygonShape2D.new()
		shape_node.points = shp
		get_parent().shape_owner_add_shape(0, shape_node)

	on_shape_updated()

func create_from_shape(shp):
	var shape = reposition_around_centroid(shp)
	
	var col_node = get_parent().get_node("CollisionPolygon2D")
	col_node.polygon = shape
	
	on_shape_updated()

func create_from_random_shape():
	create_from_shape(create_random_shape())

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

#####
#
# Helpers
#
#####
func make_point_global(point):
	return get_parent().get_global_transform().xform(point)

func make_local(shp):
	shp = shp + []
	
	# This does NOT work because the parent hasn't been added to scene tree yet
	# It's also not necessary, as we start a new, so only position is important (not rotation)
	#var trans = get_parent().get_global_transform()
	# shp[i] = trans.xform_inv(shp[i])
	
	for i in range(shp.size()):
		shp[i] -= get_parent().position
	
	return shp

func reposition_around_centroid(shp):
	shp = shp + []
	
	var centroid = calculate_centroid(shp)
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
	update() # => updates the visual drawing of the shape
	recalculate_bounding_box() 

func _draw():
	var col = Color(randf(), randf(), randf())
	
	var num_shapes = get_parent().shape_owner_get_shape_count(0)
	for i in range(num_shapes):
		var shape = get_parent().shape_owner_get_shape(0, i)
		var points = shape.points
		draw_polygon(points, [col])

#####
#
# Bounding box management
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
	
	print(bounding_box)

# TO DO: Check if these calculations are even correct
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
	for obj in bounding_box_vectors:
		if vec.dot(obj.vec) >= 0.5:
			return abs(obj.dist)
