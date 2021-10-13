extends Node2D

const MAX_VELOCITY : float = 220.0
const VELOCITY_DAMPING : float = 0.995
var speed_multiplier : float = 1.0

const MAX_ANG_VELOCITY : float = 35.0
const ANG_VELOCITY_DAMPING : float = 0.995

const BASE_GRAVITY_SCALE : float = 5.0
const ANGULAR_IMPULSE_STRENGTH : float = 200.0

const JUMP_FORCE : float = 90.0
const EXTRA_RAYCAST_MARGIN : float = 8.0

# NOTE: This force is applied _constantly_, each frame, so it should be quite low
const AIR_RESISTANCE_FORCE : float = 10.0

const STANDSTILL_THRESHOLD : float = 10.0 # in seconds
const TIME_PENALTY_STANDSTILL_TELEPORT : float = 6.0

var normal_vec : Vector2
var in_air : bool = false

var gravity_dir : int = 1

onready var body = get_parent()
onready var shaper = get_node("../Shaper")
onready var map_reader = get_node("../MapReader")
onready var clinger = get_node("../Clinger")
onready var status = get_node("../Status")

var last_input_time : float = -1
var keys_down = {
	'left': false,
	'right': false
}

func _ready():
	last_input_time = OS.get_ticks_msec()

func _on_Input_move_left():
	keys_down.left = true
	body.apply_torque_impulse(-ANGULAR_IMPULSE_STRENGTH*speed_multiplier)
	
	if in_air:
		body.apply_central_impulse(Vector2.LEFT*AIR_RESISTANCE_FORCE*speed_multiplier)
	
	last_input_time = OS.get_ticks_msec()

func _on_Input_move_right():
	keys_down.right = true
	body.apply_torque_impulse(ANGULAR_IMPULSE_STRENGTH*speed_multiplier)
	
	if in_air:
		body.apply_central_impulse(Vector2.RIGHT*AIR_RESISTANCE_FORCE*speed_multiplier)
	
	last_input_time = OS.get_ticks_msec()

func _on_Input_double_button():
	var grav_scale_absolute = abs(body.gravity_scale)
	if grav_scale_absolute == 0: grav_scale_absolute = 1.0
	
	var jump_vec = normal_vec * JUMP_FORCE * grav_scale_absolute
	body.apply_central_impulse(jump_vec)
	
	last_input_time = OS.get_ticks_msec()

func _physics_process(_dt):
	reset_gravity_strength()
	
	determine_normal_vec()
	cap_speed()
	check_for_standstill()
	
	reset_keys()
	debug_draw()

func check_for_standstill():
	if map_reader.last_cell_has_lock(): return
	
	var cur_time = OS.get_ticks_msec()
	var time_since_last_input = (cur_time - last_input_time)/1000.0
	if time_since_last_input <= STANDSTILL_THRESHOLD: return
	
	status.modify_time_penalty(TIME_PENALTY_STANDSTILL_TELEPORT)
	body.plan_teleport(map_reader.get_forward_boost_pos())
	
	# NOTE: important, otherwise it keeps endlessly teleporting of course!
	last_input_time = cur_time

func cap_speed():
	var vel = body.linear_velocity
	var ang_vel = body.angular_velocity
	
	if vel.length() > MAX_VELOCITY*speed_multiplier:
		vel *= VELOCITY_DAMPING
		body.set_linear_velocity(vel)

	if abs(ang_vel) > MAX_ANG_VELOCITY*speed_multiplier:
		ang_vel *= ANG_VELOCITY_DAMPING
		body.set_angular_velocity(ang_vel)

func reset_keys():
	keys_down.left = false
	keys_down.right = false

func reset_gravity_strength():
	body.gravity_scale = gravity_dir*BASE_GRAVITY_SCALE

func modify_gravity_strength(val):
	body.gravity_scale = gravity_dir*val*BASE_GRAVITY_SCALE

func should_modify_jump_normal():
	return clinger.active or map_reader.last_cell_has_terrain("no_gravity")

func determine_normal_vec():
	var space_state = get_world_2d().direct_space_state
	var start = body.get_global_position()
	var dirs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	
	normal_vec = Vector2.ZERO
	
	var num_hits = 0
	for dir in dirs:
		var raycast_dist = shaper.get_bounding_box_along_vec(dir) + EXTRA_RAYCAST_MARGIN
		var end = start + dir*raycast_dist
		
		var exclude = [body]
		var collision_layer = 1
		
		var result = space_state.intersect_ray(start, end, exclude, collision_layer)
		if not result: continue
		
		normal_vec += result.normal
		num_hits += 1
	
	if num_hits == 0 or not should_modify_jump_normal():
		in_air = true
		
		# NOTE: Need to do it this way
		# (Otherwise, if gravity_dir = 0, we'd have no normal vec)
		var jump_dir = 1
		if gravity_dir == -1: jump_dir = -1
		
		normal_vec = Vector2.UP*jump_dir
		return
	
	in_air = false
	normal_vec /= float(num_hits)

func debug_draw():
	$NormalVec.rotation = -body.rotation + normal_vec.angle()
