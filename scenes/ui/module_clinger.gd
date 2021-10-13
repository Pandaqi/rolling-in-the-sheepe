extends Node2D

const CLING_GRAVITY_REDUCTION : float = 0.35
const CLING_FORCE : float = 30.0
var active : bool = false

const EXTRA_RAYCAST_MARGIN : float = 8.0

var cling_vec : Vector2
var debug_cling_raycasts = []

onready var body = get_parent()
onready var shaper = get_node("../Shaper")

func _physics_process(_dt):
	if not active: return
	execute_wall_cling()

# TO DO: Now I reset the clinging vector (to zero) if you're not moving (quickly enough)
#		 Change this to allow you to just _stay clung to the wall_ when not giving input?

# TO DO: Bit of duplicate code between this one and determining normal vec (loads of raycasts) => Optimize or not?
func execute_wall_cling():
	var space_state = get_world_2d().direct_space_state
	var start = body.get_global_position()
	
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

		var raycast_dist = shaper.get_bounding_box_along_vec(dir) + EXTRA_RAYCAST_MARGIN
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

	if considered_vectors <= 0: 
		cling_vec = Vector2.ZERO
		return

	cling_vec = avg_cling_vec / float(considered_vectors)
	body.apply_central_impulse(cling_vec * CLING_FORCE)
	
	if cling_vec.y < 0:
		body.get_node("Mover").modify_gravity_strength(CLING_GRAVITY_REDUCTION)
	
	debug_draw()

func debug_draw():
	$ClingVec.rotation = cling_vec.angle()
	update()

func _draw():
	set_rotation(-body.rotation)
	
	for rc in debug_cling_raycasts:
		draw_line(Vector2.ZERO, rc - get_global_position(), Color(1,0,0), 5)
