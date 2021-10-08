extends Node2D

const SIZE : float = 20.0

func create_from_shape_list(shapes):
	var col_node = get_parent().get_node("CollisionPolygon2D")
	
	for i in range(shapes.size()):
		var shp = make_local(shapes[i])
		var shape_node = ConvexPolygonShape2D.new()
		shape_node.points = shp
		get_parent().shape_owner_add_shape(0, shape_node)

	update()

func create_from_shape(shp):
	var shape = reposition_around_centroid(shp)
	
	var col_node = get_parent().get_node("CollisionPolygon2D")
	col_node.polygon = shape
	
	update()

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

func _draw():
	var col = Color(randf(), randf(), randf())
	
	var num_shapes = get_parent().shape_owner_get_shape_count(0)
	for i in range(num_shapes):
		var shape = get_parent().shape_owner_get_shape(0, i)
		var points = shape.points
		draw_polygon(points, [col])
