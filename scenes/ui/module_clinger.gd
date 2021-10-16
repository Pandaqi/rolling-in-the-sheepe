extends Node2D

const CLING_GRAVITY_REDUCTION : float = 0.2
const CLING_FORCE : float = 60.0
var active : bool = false

const EXTRA_RAYCAST_MARGIN : float = 8.0

var cling_vec : Vector2
var size_force_multiplier : float = 1.0
var debug_cling_raycasts = []

onready var body = get_parent()
onready var shaper = get_node("../Shaper")
onready var mover = get_node("../Mover")
onready var map_reader = get_node("../MapReader")

var disabled : bool = false
onready var disable_timer = $DisableTimer

func disable():
	disabled = true
	disable_timer.start()

func _on_DisableTimer_timeout():
	disabled = false

func _physics_process(_dt):
	if disabled: return
	if not active: 
		execute_ceiling_cling()
		return
	
	size_force_multiplier = shaper.approximate_radius_as_ratio()
	execute_wall_cling()

func has_influence():
	return (cling_vec.length() >= 0.03)

func execute_ceiling_cling():
	cling_vec = Vector2.ZERO
	
	if map_reader.last_cell_has_terrain("reverse_gravity"): return
	
	var space_state = get_world_2d().direct_space_state
	var start = body.get_global_position()
	
	var result = shoot_raycast_in_dir(Vector2.UP)
	if not result: return

	var movement_help_factor : float = 0.33
	cling_vec = Vector2.UP
	if mover.keys_down.left:
		cling_vec += movement_help_factor*Vector2.RIGHT
	elif mover.keys_down.right:
		cling_vec += movement_help_factor*Vector2.LEFT
	
	# TESTING: smaller vector, smaller force
	cling_vec = 0.5*cling_vec.normalized()
	
	apply_cling_vec(cling_vec)

# TO DO: Now I reset the clinging vector (to zero) if you're not moving (quickly enough)
#		 Change this to allow you to just _stay clung to the wall_ when not giving input?

# TO DO: Bit of duplicate code between this one and determining normal vec (loads of raycasts) => Optimize or not?
func execute_wall_cling():
	#var dirs = [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]
	var dirs = [Vector2.RIGHT, Vector2.DOWN, Vector2.UP]
	
	var avg_cling_vec = Vector2.ZERO
	var considered_vectors = 0
	
	var moving_dir = body.get_linear_velocity()
	if moving_dir.length() <= 5.0:
		cling_vec = Vector2.ZERO
		return
	
	var moving_angle = moving_dir.angle()
	
	debug_cling_raycasts = []
	
	for i in range(dirs.size()):
		var dir = dirs[i]
		dir = dir.rotated(moving_angle)
		
		var result = shoot_raycast_in_dir(dir)
		if not result: continue
		
		# the first dir is our "current movement direction"
		# by strongly preferring it, we never "stop moving"
		var weight = 1.0
		if i == 0: weight = 3.0
		
		avg_cling_vec += weight*dir
		considered_vectors += weight

	if considered_vectors <= 0: 
		cling_vec = Vector2.ZERO
		return
	
	cling_vec = avg_cling_vec / float(considered_vectors)
	
	apply_cling_vec(cling_vec)

func apply_cling_vec(vec):
	var my_cling_force = CLING_FORCE*size_force_multiplier
	body.apply_central_impulse(vec * my_cling_force)
	
	if vec.y < 0:
		body.get_node("Mover").modify_gravity_strength(CLING_GRAVITY_REDUCTION)
	
	debug_draw()

func debug_draw():
	return
	$ClingVec.rotation = cling_vec.angle()
	update()

func _draw():
	set_rotation(-body.rotation)
	
	for rc in debug_cling_raycasts:
		draw_line(Vector2.ZERO, rc - get_global_position(), Color(1,0,0), 5)
	
	debug_cling_raycasts = []

func shoot_raycast_in_dir(dir):
	var space_state = get_world_2d().direct_space_state
	var start = body.get_global_position()
	var raycast_dist = shaper.get_bounding_box_along_vec(dir) + EXTRA_RAYCAST_MARGIN
	var end = start + dir*raycast_dist
	
	debug_cling_raycasts.append(end)

	var exclude = [body]
	var collision_layer = 2
	
	var result = space_state.intersect_ray(start, end, exclude, collision_layer)
	return result
