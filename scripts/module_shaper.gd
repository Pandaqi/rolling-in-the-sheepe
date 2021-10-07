extends Node2D

const SIZE : float = 100.0

var shape = null

func _ready():
	if not shape:
		create_random_shape()
	
	reposition_around_centroid()
	create_body_from_shape()

func create_random_shape():
	shape = []
	
	var ang = 0
	var avg_ang_jump = 0.2*PI
	var ang_jump_error = 1.0
	
	var avg_radius = SIZE
	var avg_radius_error = 1.0
	
	while ang < 2*PI:
		var radius = (1.0 + (randf() - 0.5)*avg_radius_error)*avg_radius
		var p = Vector2(cos(ang), sin(ang))*radius
		
		shape.append(p)
		
		ang += (1.0 + (randf()-0.5)*ang_jump_error)*avg_ang_jump
	
	update()

func reposition_around_centroid():
	var centroid = calculate_centroid(shape)

	for i in range(shape.size()):
		shape[i] -= centroid
	
	update()

func create_body_from_shape():
	var col_node = CollisionPolygon2D.new()
	col_node.polygon = shape
	
	get_parent().call_deferred("add_child", col_node)

func calculate_centroid(shp):
	var avg = Vector2.ZERO
	for point in shp:
		avg += point
	
	return avg / float(shp.size())

func _draw():
	var col = Color(randf(), randf(), randf())
	draw_polygon(shape, [col])
