extends Node

const GROW_FACTOR : float = 0.2
const GROW_TIMER_DURATION : float = 3.0
const BASE_TIMER_DURATION : float = 7.0
var final_timer_duration

# if the algorithm moved the points LESS than this,
# we are considered "already round", which will save us tons of computations later
const MOVEMENT_THRESHOLD_BEFORE_ROUND : float = 7.0
const RADIUS_INCREASE_FOR_ROUNDING : float = 3.0

var average_airtime : float = 0.0

var grow_instead_of_rounding : float = false
var reverse_rounding : float = false

const FAST_MODE_SPEEDUP : float = 0.45 # lower is faster; it's a percentage of the total time; 1.0 is the neutral operation
var fast_mode : bool = false
var fast_mode_dir : String = ""

var grow_mode = ""

const ROUNDING_THRESHOLD : float = 0.25

onready var body = get_parent()

onready var round_algo_timer = $Timer
onready var grow_timer = $GrowTimer

func _ready():
	final_timer_duration = (1.0 + 0.2*(randf()-0.5))*BASE_TIMER_DURATION
	round_algo_timer.wait_time = final_timer_duration
	round_algo_timer.start()

func _physics_process(dt):
	if body.mover.in_air: average_airtime += dt

func restart_timer():
	round_algo_timer.stop()
	
	var mult = 1.0
	if fast_mode: mult = FAST_MODE_SPEEDUP
	round_algo_timer.wait_time = mult*final_timer_duration
	
	round_algo_timer.start()

func restart_grow_timer():
	grow_timer.stop()
	
	var mult = 1.0
	if fast_mode: mult = FAST_MODE_SPEEDUP
	grow_timer.wait_time = mult*GROW_TIMER_DURATION
	
	grow_timer.start()

func _on_Timer_timeout():
	average_airtime /= final_timer_duration
	
	# We now have a value between 0->1 which tells us which FRACTION of that time we spent not-rolling
	var what_to_do = "round"
	if average_airtime > 0.5: what_to_do = "malform"
	
	if GDict.cfg.only_round_if_airtime_at_extremes:
		what_to_do = null
		var threshold = ROUNDING_THRESHOLD
		
		if average_airtime < threshold: what_to_do = "round"
		elif average_airtime > (1.0 - threshold): what_to_do = "malform"
	
	# ITEM: going fast-tracked to a certain value
	if fast_mode:
		if fast_mode_dir == 'round': what_to_do = "round"
		else: what_to_do = "malform"
	
	if reverse_rounding:
		if what_to_do == "round": what_to_do = "malform"
		else: what_to_do = "round"

	if what_to_do == "round": become_more_round_unrealistic()
	elif what_to_do == "malform": become_more_malformed_unrealistic()

	average_airtime = 0.0

func become_more_round_unrealistic():
	if body.status.is_wolf: return
	
	if grow_instead_of_rounding:
		grow(GROW_FACTOR)
		return
	
	if body.shaper.is_fully_round(): return
	
	var new_shape_name = change_shape_index(+1)
	var new_body = body.slicer.create_basic_body(body, new_shape_name)

	GAudio.play_dynamic_sound(body, "plop_single")
	body.shaper.create_new_from_shape(new_body, { 'type': new_shape_name })
	
	if feedback_enabled(): body.feedback.create_for_node(body, "+ Rounder!")

func become_more_malformed_unrealistic():
	if body.status.is_wolf: return
	
	if grow_instead_of_rounding:
		shrink(GROW_FACTOR)
		return
	if body.shaper.is_fully_malformed(): return
	
	var new_shape_name = change_shape_index(-1)
	var new_body = body.slicer.create_basic_body(body, new_shape_name)
	
	GAudio.play_dynamic_sound(body, "plop_single")
	body.shaper.create_new_from_shape(new_body, { 'type': new_shape_name })
	
	if feedback_enabled(): body.feedback.create_for_node(body, "- Sharper!")

func make_fully_round():
	var new_body = body.slicer.create_basic_body(body, "circle")
	
	GAudio.play_dynamic_sound(body, "plop_multiple")
	body.shaper.create_new_from_shape(new_body, { 'type': "circle" })

func make_fully_malformed():
	var new_body = body.slicer.create_basic_body(body, "triangle")
	
	GAudio.play_dynamic_sound(body, "plop_multiple")
	body.shaper.create_new_from_shape(new_body, { 'type': "triangle" })

func get_next_index(val):
	var cur_shape = body.shaper.shape_type
	var cur_index = GDict.shape_order.find(cur_shape)
	
	if cur_index < 0:
		var related_basic_shape = GDict.shape_list[cur_shape].basic
		cur_index = GDict.shape_order.find(related_basic_shape)
	
	return clamp(cur_index + val, 0, GDict.shape_order.size()-1)

func change_shape_index(val):
	var next_index = get_next_index(val) 
	return GDict.shape_order[next_index]

func feedback_enabled():
	return not fast_mode

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
	if body.shaper.at_max_size(): return
	if feedback_enabled(): body.feedback.create_for_node(body, "Grow!")
	
	var factor = body.shaper.clamp_growth_factor(1.0 + val)
	change_size(factor)

func shrink(val):
	if body.shaper.at_min_size(): return
	if feedback_enabled(): body.feedback.create_for_node(body, "Shrink!")
	
	var factor = body.shaper.clamp_growth_factor(1.0 - val)
	change_size(factor)

func grow_to_max_size():
	grow(1000)

func shrink_to_min_size():
	shrink(1000)

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

	body.shaper.on_shape_updated()

func _on_GrowTimer_timeout():
	if grow_mode == "": return
	
	if grow_mode == "grow":
		grow(0.1)
	elif grow_mode == "shrink":
		shrink(0.1)

#
# Fast mode => used by items/powerups to more quickly go towards something
#
func enable_fast_mode(dir : String):
	fast_mode = true
	fast_mode_dir = dir
	
	restart_timer()
	restart_grow_timer()
	
	var mode = 'grow'
	if dir == 'sharp': mode = 'shrink'
	start_grow_mode(mode)
	
	call_deferred("_on_Timer_timeout")
	call_deferred("_on_GrowTimer_timeout")

func disable_fast_mode():
	fast_mode = false
	fast_mode_dir = ""
	
	restart_timer()
	restart_grow_timer()
	end_grow_mode()
