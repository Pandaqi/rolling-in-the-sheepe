extends Node2D

const BASE_GRAVITY_SCALE : float = 5.0
const ANGULAR_IMPULSE_STRENGTH : float = 200.0
const JUMP_IMPULSE_STRENGTH : float = 60.0

const CLING_RAYCAST_DIST : float = 40.0
const CLING_FORCE : float = 30.0

var cling_vec

var keys_down = {
	'left': false,
	'right': false
}

func _on_Input_move_left():
	keys_down.left = true
	get_parent().apply_torque_impulse(-ANGULAR_IMPULSE_STRENGTH)

func _on_Input_move_right():
	keys_down.right = true
	get_parent().apply_torque_impulse(ANGULAR_IMPULSE_STRENGTH)

func _on_Input_double_button():
	var jump_vec = -cling_vec
	if jump_vec.length() <= 0.05:
		jump_vec = Vector2.UP
	
	get_parent().apply_central_impulse(jump_vec * JUMP_IMPULSE_STRENGTH * get_parent().gravity_scale)

func _physics_process(dt):
	execute_wall_cling()
	
	keys_down.left = false
	keys_down.right = false

		
# TO DO: Add clingable objects to their own layer?
#        Or should you also cling to other players??
func execute_wall_cling():
	get_parent().gravity_scale = 0.5*BASE_GRAVITY_SCALE
	
	var space_state = get_world_2d().direct_space_state
	var start = get_parent().get_global_position()
	
	#var dirs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	var dirs = [Vector2.RIGHT, Vector2.DOWN, Vector2.UP]
	
	var avg_cling_vec = Vector2.ZERO
	var considered_vectors = 0
	
	var moving_dir = get_parent().get_linear_velocity()
	var moving_dir_norm = moving_dir.normalized()
	if moving_dir.length() <= 5.0:
		if keys_down.right:
			moving_dir = Vector2.RIGHT
		elif keys_down.left: 
			moving_dir = Vector2.LEFT
	
	var moving_angle = moving_dir.angle()
	
	for dir in dirs:
		#if moving_dir.dot(dir) <= 0: continue
		dir = dir.rotated(moving_angle)
		
		var end = start + dir*CLING_RAYCAST_DIST
	
		var exclude = [get_parent()]
		var collision_layer = 1
		
		var result = space_state.intersect_ray(start, end, exclude, collision_layer)
		if not result: continue
		
		var cling_dir = -result.normal
		
		# DEBUGGING: using the normal somehow only _stops_ us, but doesn't propel us forward
		cling_dir = dir
		
		avg_cling_vec += cling_dir
		considered_vectors += 1
	
	if considered_vectors <= 0: return

	cling_vec = avg_cling_vec / float(considered_vectors)
	get_parent().apply_central_impulse(cling_vec * CLING_FORCE)
	
	if cling_vec.y < 0:
		get_parent().gravity_scale = 0.5*BASE_GRAVITY_SCALE
	
