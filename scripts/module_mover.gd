extends Node2D

onready var body = get_parent()

const MAX_VELOCITY : float = 220.0
const MAX_VELOCITY_AIR : float = 150.0

const VELOCITY_DAMPING : float = 0.995
var speed_multiplier : float = 1.0

const WOLF_BONUS_SPEED : float = 2.0
var size_speed_multiplier : float = 1.0

const MAX_ANG_VELOCITY : float = 35.0
const ANG_VELOCITY_DAMPING : float = 0.995

const BASE_GRAVITY_SCALE : float = 5.0
const ANGULAR_IMPULSE_STRENGTH : float = 200.0

const JUMP_FORCE : float = 90.0
const EXTRA_RAYCAST_MARGIN : float = 8.0

# NOTE: This force is applied _constantly_, each frame, so it should be quite low
const AIR_RESISTANCE_FORCE : float = 8.0

const STANDSTILL_THRESHOLD : float = 10.0 # in seconds
const TIME_PENALTY_STANDSTILL_TELEPORT : float = 6.0

var normal_vec : Vector2
var jump_vec : Vector2
var in_air : bool = false

var velocity_last_frame : Vector2

var gravity_dir : int = 1

var air_break : bool = false
var air_break_start : float = -1
var air_break_time_limit : float = 230.0

var last_input_time : float = -1
var keys_down = {
	'left': false,
	'right': false
}

func _ready():
	last_input_time = OS.get_ticks_msec()

func _on_Input_move_left():
	keys_down.left = true
	last_input_time = OS.get_ticks_msec()
	
	if air_break: return
	
	var torque = -ANGULAR_IMPULSE_STRENGTH*speed_multiplier*size_speed_multiplier*gravity_dir
	body.apply_torque_impulse(torque)
	
	if in_air:
		var air_force = Vector2.LEFT*AIR_RESISTANCE_FORCE*speed_multiplier*size_speed_multiplier
		body.apply_central_impulse(air_force)

func _on_Input_move_left_released():
	keys_down.left = false
	air_break = false

func _on_Input_move_right():
	keys_down.right = true
	last_input_time = OS.get_ticks_msec()
	
	if air_break: return
	
	var torque = ANGULAR_IMPULSE_STRENGTH*speed_multiplier*size_speed_multiplier*gravity_dir
	body.apply_torque_impulse(torque)
	
	if in_air:
		var air_force = Vector2.RIGHT*AIR_RESISTANCE_FORCE*speed_multiplier*size_speed_multiplier
		body.apply_central_impulse(air_force)

func _on_Input_move_right_released():
	keys_down.right = false
	air_break = false

func _on_Input_double_button():
	jump()

func jump():
	air_break = false
	last_input_time = OS.get_ticks_msec()
	
	var used_input_for_airbreak = (OS.get_ticks_msec() - air_break_start) > air_break_time_limit
	if used_input_for_airbreak: return
	
	GAudio.play_dynamic_sound(body, "jump")
	
	# NOTE: It enables itself again after a (very) short period
	body.clinger.disable()
	
	var grav_scale_absolute = abs(body.gravity_scale)
	if grav_scale_absolute == 0: grav_scale_absolute = 1.0

	var final_jump_vec = jump_vec * JUMP_FORCE * grav_scale_absolute * size_speed_multiplier
	body.apply_central_impulse(final_jump_vec)

func _physics_process(_dt):
	size_speed_multiplier = body.shaper.approximate_radius_as_ratio()
	if body.status.is_wolf: size_speed_multiplier *= WOLF_BONUS_SPEED
	
	reset_gravity_strength()
	
	check_for_air_break()
	determine_normal_vec()
	cap_speed()
	check_for_standstill()

	debug_draw()
	
	velocity_last_frame = body.get_linear_velocity()

func check_for_air_break():
	if not keys_down.right: return
	if not keys_down.left: return
	
	var used_input_for_jump = (OS.get_ticks_msec() - air_break_start) <= air_break_time_limit
	if used_input_for_jump: return
	
	if not air_break:
		air_break = true
		air_break_start = OS.get_ticks_msec()
		
		var new_x_vel = body.linear_velocity.x * (1.15 + abs(body.linear_velocity.y) / float(MAX_VELOCITY))
		body.linear_velocity.x = clamp(new_x_vel, -MAX_VELOCITY, MAX_VELOCITY)
		
		GAudio.play_dynamic_sound(body, "float")
	
	body.gravity_scale = 0.0
	body.linear_velocity.y = 0.0

func check_for_standstill():
	if body.status.is_menu: return
	if body.status.has_finished: return
	if body.map_reader.last_cell_has_lock(): return
	
	var cur_time = OS.get_ticks_msec()
	
	var time_since_last_input = (cur_time - last_input_time)/1000.0
	if time_since_last_input <= STANDSTILL_THRESHOLD: return
	
	body.status.modify_time_penalty(TIME_PENALTY_STANDSTILL_TELEPORT)
	body.plan_teleport(body.map_reader.get_forward_boost_pos(), "Stood still too long!")
	
	# NOTE: important, otherwise it keeps endlessly teleporting of course!
	last_input_time = cur_time

func cap_speed():
	var vel = body.linear_velocity
	var ang_vel = body.angular_velocity
	
	var cur_max = MAX_VELOCITY
	if in_air: cur_max = MAX_VELOCITY_AIR
	
	if vel.length() > cur_max*speed_multiplier:
		vel *= VELOCITY_DAMPING
		body.set_linear_velocity(vel)

	if abs(ang_vel) > MAX_ANG_VELOCITY*speed_multiplier:
		ang_vel *= ANG_VELOCITY_DAMPING
		body.set_angular_velocity(ang_vel)

func reset_gravity_strength():
	body.gravity_scale = gravity_dir*BASE_GRAVITY_SCALE

func modify_gravity_strength(val):
	body.gravity_scale = gravity_dir*val*BASE_GRAVITY_SCALE

func should_modify_jump_normal():
	if body.status.is_menu: return false
	return body.clinger.has_influence() or body.map_reader.last_cell_has_terrain("no_gravity")

func determine_normal_vec():
	var space_state = get_world_2d().direct_space_state
	var start = body.get_global_position()
	var dirs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	
	normal_vec = Vector2.ZERO
	jump_vec = Vector2.ZERO
	
	var num_hits = 0
	var sides_with_hit = [false,false,false,false]
	for i in range(4):
		var dir = dirs[i]
		var raycast_dist = body.shaper.get_bounding_box_along_vec(dir) + EXTRA_RAYCAST_MARGIN
		var end = start + dir*raycast_dist
		
		var exclude = [body]
		var collision_layer = 1
		
		var result = space_state.intersect_ray(start, end, exclude, collision_layer)
		if not result: continue
		
		sides_with_hit[i] = true
		normal_vec += result.normal
		num_hits += 1
	
	in_air = (num_hits <= 0)
	if not in_air: normal_vec /= float(num_hits) # without if-check there's div by 0
	
	jump_vec = normal_vec
	
	if num_hits == 0 or not should_modify_jump_normal():
		# NOTE: Need to do it this way
		# (Otherwise, if gravity_dir = 0, we'd have no normal vec)
		var jump_dir = 1
		if gravity_dir == -1: jump_dir = -1

		# TO DO: move outside this if-statement? Nah, would cause other troubles
		var extra_vec = Vector2.ZERO
		var factor = GDict.cfg.wall_jump_strength
		
		if sides_with_hit[0]:
			extra_vec += Vector2.LEFT
		if sides_with_hit[2]:
			extra_vec += Vector2.RIGHT
			
		jump_vec = (Vector2.UP + factor*extra_vec).normalized() * jump_dir

		return

func debug_draw():
	$NormalVec.rotation = -body.rotation + normal_vec.angle()
