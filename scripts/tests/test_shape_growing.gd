extends RigidBody2D

func _input(ev):
	if ev.is_action_released("ui_right"):
		change_size(1.1)
	elif ev.is_action_released("ui_left"):
		change_size(0.9)

func make_global(shp):
	shp = shp + []
	
	var trans = get_global_transform()
	for i in range(shp.size()):
		shp[i] = trans.xform(shp[i])
	
	return shp

func change_size(factor):
	var num_shapes = shape_owner_get_shape_count(0)
	var shapes_to_add = []
	
	var center = get_global_position()
	var trans = get_global_transform()
	for i in range(num_shapes):
		var shape = shape_owner_get_shape(0, i)

		var pts = Array(shape.points)
		
		for a in range(pts.size()):
			pts[a] = ((trans.xform(pts[a]) - center) * factor).rotated(-rotation)
		
		shapes_to_add.append(pts)
	
	for shp in shapes_to_add:
		var new_shape = ConvexPolygonShape2D.new()
		new_shape.points = shp
		shape_owner_remove_shape(0, 0)
		shape_owner_add_shape(0, new_shape)

	update()

func _draw():
	var color = Color(0,0,0)
	var num_shapes = shape_owner_get_shape_count(0)
	for i in range(num_shapes):
		var shape = shape_owner_get_shape(0, i)
		var points = shape.points
		draw_polygon(points, [color])
