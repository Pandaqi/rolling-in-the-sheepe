extends Node

const GROW_FACTOR : float = 0.2
const BASE_TIMER_DURATION : float = 5.0
var final_timer_duration

# if the algorithm moved the points LESS than this,
# we are considered "already round", which will save us tons of computations later
const MOVEMENT_THRESHOLD_BEFORE_ROUND : float = 7.0
const RADIUS_INCREASE_FOR_ROUNDING : float = 3.0

var average_airtime : float = 0.0
var is_round : float = false
var is_malformed : float = false

var grow_instead_of_rounding : float = false
var reverse_rounding : float = false

var grow_mode = ""

onready var body = get_parent()
onready var status = get_node("../Status")
onready var shaper = get_node("../Shaper")
onready var mover = get_node("../Mover")

onready var slicer = get_node("/root/Main/Slicer")
onready var round_algo_timer = $Timer
onready var grow_timer = $GrowTimer

func _ready():
	final_timer_duration = (1.0 + 0.2*(randf()-0.5))*BASE_TIMER_DURATION
	round_algo_timer.wait_time = final_timer_duration
	round_algo_timer.start()

func _physics_process(dt):
	if mover.in_air: average_airtime += dt

func _on_Timer_timeout():
	average_airtime /= final_timer_duration
	
	# We now have a value between 0->1 which tells us which FRACTION
	# of that time we spent not-rolling
	var what_to_do = "round"
	if average_airtime > 0.5: what_to_do = "malform"
		
	else:
		if GDict.cfg.unrealistic_rounding:
			become_more_round_unrealistic()
		else:
			become_more_round()
	
	if reverse_rounding:
		if what_to_do == "round": what_to_do = "malform"
		else: what_to_do = "round"
	
	if what_to_do == "round":
		if GDict.cfg.unrealistic_rounding:
			become_more_round_unrealistic()
		else:
			become_more_round()
	elif what_to_do == "malform":
		if GDict.cfg.unrealistic_rounding:
			become_more_malformed_unrealistic()
		else:
			become_more_malformed()
	
	average_airtime = 0.0

func become_more_round_unrealistic():
	if status.is_wolf: return
	
	if grow_instead_of_rounding:
		grow(GROW_FACTOR)
		return
	if is_round: return
	
	var new_shape_name = change_shape_index(+1)
	var new_body = slicer.create_basic_body(body, new_shape_name)
	
	shaper.create_new_from_shape(new_body, { 'type': new_shape_name })
	
	is_round = false
	if new_shape_name == "circle": is_round = true

func become_more_malformed_unrealistic():
	if status.is_wolf: return
	
	if grow_instead_of_rounding:
		shrink(GROW_FACTOR)
		return
	if is_malformed: return
	
	var new_shape_name = change_shape_index(-1)
	var new_body = slicer.create_basic_body(body, new_shape_name)
	
	shaper.create_new_from_shape(new_body, { 'type': new_shape_name })
	
	is_malformed = false
	if new_shape_name == "triangle": is_malformed = true

func make_fully_round():
	var new_body = slicer.create_basic_body(body, "circle")
	
	shaper.create_new_from_shape(new_body, { 'type': "circle" })

func make_fully_malformed():
	var new_body = slicer.create_basic_body(body, "triangle")
	
	shaper.create_new_from_shape(new_body, { 'type': "triangle" })

func change_shape_index(val):
	var cur_shape = shaper.shape_type
	var cur_index = GDict.shape_order.find(cur_shape)
	
	if cur_index < 0:
		var related_basic_shape = GDict.shape_list[cur_shape].basic
		cur_index = GDict.shape_order.find(related_basic_shape)
	
	var next_index = clamp(cur_index + val, 0, GDict.shape_order.size()-1)
	return GDict.shape_order[next_index]

#
# Deforming
#  => These functions are basically useless now, as I don't think I'll ever activate this system again ...
#

# TO DO: Ensure minimum dimensions here as well
# (Maybe just require all points to be some distance away from Vector2.ZERO?)

# TO DO: This doesn't even work, as points that are _overlapping_ ( = matching) wiill get sent in different directions ... unless I _seed_ the randomness based on rounded coordinates?
func become_more_malformed():
	print("MALFORM!")
	
	if status.is_wolf: return
	
	var ratio = average_airtime
	if grow_instead_of_rounding:
		shrink(GROW_FACTOR*ratio)
		return
	if is_malformed: return
	
	# DEBUGGING => have to figure this out first
	return 
	
	var num_shapes = body.shape_owner_get_shape_count(0)
	for i in range(num_shapes):
		var shape = body.shape_owner_get_shape(0, i)
		shape.points = move_points_randomly(shape.points)
	
	shaper.reposition_all_around_centroid()
	shaper.on_shape_updated()

func move_points_randomly(shp):
	for i in range(shp.size()):
		shp[i] += Vector2(randf(), randf())
	
	return shp

#
# Rounding
#
func become_more_round():
	if status.is_wolf: return
	
	var ratio = 1.0 - average_airtime
	if grow_instead_of_rounding:
		grow(GROW_FACTOR*ratio)
		return
	if is_round: return
	
	var num_shapes = body.shape_owner_get_shape_count(0)
	var shapes_to_add = []
	
	var total_number_of_points : int = 0
	for i in range(num_shapes):
		var shape = body.shape_owner_get_shape(0, i)
		total_number_of_points += shape.points.size()
	
	var should_enrich_shape = (total_number_of_points / float(num_shapes)) <= 5
	
	var avg_pos : Vector2 = Vector2.ZERO
	var total_points_considered : int = 0
	
	for i in range(num_shapes):
		var shape = body.shape_owner_get_shape(0, i)
		var pts = Array(shape.points)
		
		if should_enrich_shape:
			pts = enrich_shape(pts)
		
		var new_points = move_points_to_circle(pts, ratio)
		
		for p in new_points:
			avg_pos += p
			total_points_considered += 1
		
		shapes_to_add.append(new_points)
	
	# reposition all points around centroid
	var offset = avg_pos/float(total_points_considered)
	for shp in shapes_to_add:
		for i in range(shp.size()):
			shp[i] = (shp[i] - offset).rotated(-body.rotation)
	
	for shp in shapes_to_add:
		var new_shape = ConvexPolygonShape2D.new()
		new_shape.points = shp
		body.shape_owner_remove_shape(0, 0)
		body.shape_owner_add_shape(0, new_shape)
	
	shaper.on_shape_updated()

func move_points_to_circle(shp, ratio):
	var c = body.get_global_position()
	var radius = shaper.approximate_radius() + RADIUS_INCREASE_FOR_ROUNDING
	
	var total_movement = 0
	
	shp = shaper.make_global(shp)
	for i in range(shp.size()):
		var p = shp[i] - c
		var ang = snap_angle(p.angle())
		var circle_pos = Vector2(cos(ang), sin(ang))*radius
		
		var new_pos = p.linear_interpolate(circle_pos, 0.5*ratio)
		shp[i] = new_pos
		
		total_movement += (new_pos - p).length()
	
	if total_movement < MOVEMENT_THRESHOLD_BEFORE_ROUND:
		is_round = true
	
	return shp

func snap_angle(ang):
	var num_points : float = 16.0
	
	return round(ang / (2.0*PI) * num_points) * (2.0*PI) / num_points

func enrich_shape(shp):
	print(shp)
	
	var i = 0
	while i < shp.size():
		var next_i = (i + 1) % int(shp.size())
		var p1 = shp[i]
		var p2 = shp[next_i]
		
		var half_point = 0.5 * (p1 + p2)
		
		shp.insert(i+1, half_point)
		i += 2 # skip the point we just inserted
	
	return shp

#
# Growing/Shrinking
# (basically a heavily simplified version of the round/deform algorithms)
#
func start_grow_mode(mode):
	grow_mode = mode
	grow_timer.start()

func end_grow_mode():
	grow_mode = ""
	grow_timer.stop()

func grow(val):
	if shaper.at_max_size(): return
	change_size(1.0 + val)

func shrink(val):
	if shaper.at_min_size(): return
	change_size(1.0 - val)

func change_size(factor):
	var num_shapes = body.shape_owner_get_shape_count(0)
	var shapes_to_add = []
	
	var center = body.get_global_position()
	var trans = body.get_global_transform()
	for i in range(num_shapes):
		var shape = body.shape_owner_get_shape(0, i)

		var pts = Array(shape.points)
		
		for a in range(pts.size()):
			pts[a] = ((trans.xform(pts[a]) - center) * factor).rotated(-body.rotation)
		
		shapes_to_add.append(pts)
	
	for _i in range(num_shapes):
		body.shape_owner_remove_shape(0,0)
	
	for shp in shapes_to_add:
		var new_shape = ConvexPolygonShape2D.new()
		new_shape.points = shp
		body.shape_owner_add_shape(0, new_shape)

	shaper.on_shape_updated()

func _on_GrowTimer_timeout():
	if grow_mode == "": return
	
	if grow_mode == "grow":
		grow(0.1)
	elif grow_mode == "shrink":
		shrink(0.1)
