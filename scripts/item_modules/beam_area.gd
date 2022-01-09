extends Node2D

var default_tip_pos : Vector2 = Vector2.RIGHT*36
var local_end_point : Vector2 = Vector2.ZERO

onready var sprite = $Sprite
onready var area = $Area2D
onready var col_node = $Area2D/CollisionShape2D
var col_shape

var disabled : bool = false
onready var beam_tip = $BeamTip

var max_tile_dist : int = 5

func _ready():
	col_shape = col_node.shape.duplicate(true)
	col_node.shape = col_shape
	
	beam_tip.set_position(default_tip_pos)

func _physics_process(dt):
	shoot_raycast()
	position_laser()

func set_starting_point(offset : Vector2):
	beam_tip.position = offset

func set_max_tile_dist(dist : int):
	max_tile_dist = dist

func set_beam_modulate(mod : Color):
	sprite.modulate = mod

func shoot_raycast():
	if disabled: return
	
	var space_state = get_world_2d().direct_space_state
	var start = beam_tip.global_position
	var normal = global_transform.x
	var end = start + normal*max_tile_dist*64

	var collision_layer = 2
	var result = space_state.intersect_ray(start, end, [], collision_layer)
	if not result: 
		local_end_point = end - start
		return

	local_end_point = result.position - start

func position_laser():
	if disabled: return
	
	sprite.set_position(beam_tip.position)
	
	# make laser so its length is precisely towards the first point it hits
	var length = local_end_point.length()
	var x_scale = length / 64.0
	
	sprite.scale.x = x_scale

	# collision shapes are always centered
	# so resize then move to match the sprite
	area.set_position(sprite.position + Vector2.RIGHT * 0.5 * length)
	col_shape.extents.x = 0.5 * length

func disable():
	disabled = true
	set_visible(false)
	col_shape.extents.x = 0
	
	print("DISABLE")

func enable():
	disabled = false
	set_visible(true)
	
	print("ENABLE")
