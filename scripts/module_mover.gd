extends Node2D

const BASE_GRAVITY_SCALE : float = 5.0
const ANGULAR_IMPULSE_STRENGTH : float = 200.0

const JUMP_FORCE : float = 90.0

const CLING_GRAVITY_REDUCTION : float = 0.35
const CLING_FORCE : float = 30.0
var clinging_active : bool = false

const EXTRA_RAYCAST_MARGIN : float = 8.0

# NOTE: This force is applied _constantly_, each frame, so it should be quite low
const AIR_RESISTANCE_FORCE : float = 10.0

var normal_vec : Vector2
var cling_vec : Vector2
var debug_cling_raycasts = []
var in_air : bool = false

var speed_multiplier : float = 1.0

var gravity_dir : int = 1

onready var body = get_parent()

var keys_down = {
	'left': false,
	'right': false
}

func _on_Input_move_left():
	keys_down.left = true
	body.apply_torque_impulse(-ANGULAR_IMPULSE_STRENGTH*speed_multiplier)
	
	if in_air:
		body.apply_central_impulse(Vector2.LEFT*AIR_RESISTANCE_FORCE*speed_multiplier)

func _on_Input_move_right():
	keys_down.right = true
	body.apply_torque_impulse(ANGULAR_IMPULSE_STRENGTH*speed_multiplier)
	
	if in_air:
		body.apply_central_impulse(Vector2.RIGHT*AIR_RESISTANCE_FORCE*speed_multiplier)

func _on_Input_double_button():
	var grav_scale_absolute = abs(body.gravity_scale)
	if grav_scale_absolute == 0: grav_scale_absolute = 1.0
	
	var jump_vec = normal_vec * JUMP_FORCE * grav_scale_absolute
	body.apply_central_impulse(jump_vec)

func _physics_process(dt):
	body.gravity_scale = gravity_dir*BASE_GRAVITY_SCALE
	
	determine_normal_vec()
	execute_wall_cling()
	
	keys_down.left = false
	keys_down.right = false
	
	$NormalVec.rotation = -body.rotation + normal_vec.angle()
	$ClingVec.rotation = -body.rotation + cling_vec.angle()

func determine_normal_vec():
	var space_state = get_world_2d().direct_space_state
	var start = body.get_global_position()
	var dirs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	
	normal_vec = Vector2.ZERO
	
	var num_hits = 0
	for dir in dirs:
		var raycast_dist = body.get_node("Shaper").get_bounding_box_along_vec(dir) + EXTRA_RAYCAST_MARGIN
		var end = start + dir*raycast_dist
		
		var exclude = [body]
		var collision_layer = 1
		
		var result = space_state.intersect_ray(start, end, exclude, collision_layer)
		if not result: continue
		
		normal_vec += result.normal
		num_hits += 1
	
	if num_hits == 0:
		in_air = true
		
		# NOTE: Need to do it this way
		# (Otherwise, if gravity_dir = 0, we'd have no normal vec)
		var jump_dir = 1
		if gravity_dir == -1: jump_dir = -1
		
		normal_vec = Vector2.UP*jump_dir
		return
	
	in_air = false
	normal_vec /= float(num_hits)

# TO DO: Now I reset the clinging vector (to zero) if you're not moving (quickly enough)
#		 Change this to allow you to just _stay clung to the wall_ when not giving input?

# TO DO: Bit of duplicate code between this one and determining normal vec (loads of raycasts) => Optimize or not?

func execute_wall_cling():
	if not clinging_active: return
	
	var space_state = get_world_2d().direct_space_state
	var start = body.get_global_position()
	
	#var dirs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	var dirs = [Vector2.RIGHT, Vector2.DOWN, Vector2.UP]
	
	var avg_cling_vec = Vector2.ZERO
	var considered_vectors = 0
	
	var moving_dir = body.get_linear_velocity()
	var moving_dir_norm = moving_dir.normalized()
	if moving_dir.length() <= 5.0:
		cling_vec = Vector2.ZERO
		return
		
		if keys_down.right:
			moving_dir = Vector2.RIGHT
		elif keys_down.left: 
			moving_dir = Vector2.LEFT
	
	var moving_angle = moving_dir.angle()
	
	debug_cling_raycasts = []
	
	for i in range(dirs.size()):
		var dir = dirs[i]
		
		dir = dir.rotated(moving_angle)

		var raycast_dist = body.get_node("Shaper").get_bounding_box_along_vec(dir) + EXTRA_RAYCAST_MARGIN
		var end = start + dir*raycast_dist
		
		debug_cling_raycasts.append(end)
	
		var exclude = [body]
		var collision_layer = 2
		
		var result = space_state.intersect_ray(start, end, exclude, collision_layer)
		if not result: continue
		
		var cling_dir = dir
		
		# the first dir is our "current movement direction"
		# by strongly preferring it, we never "stop moving"
		var weight = 1.0
		if i == 0: weight = 3.0
		
		avg_cling_vec += weight*cling_dir
		considered_vectors += weight
	
	update()
	
	if considered_vectors <= 0: 
		cling_vec = Vector2.ZERO
		return

	cling_vec = avg_cling_vec / float(considered_vectors)
	body.apply_central_impulse(cling_vec * CLING_FORCE)
	
	if cling_vec.y < 0:
		body.gravity_scale = gravity_dir*CLING_GRAVITY_REDUCTION*BASE_GRAVITY_SCALE

func _draw():
	set_rotation(-body.rotation)
	
	for rc in debug_cling_raycasts:
		draw_line(Vector2.ZERO, rc - get_global_position(), Color(1,0,0), 5)
