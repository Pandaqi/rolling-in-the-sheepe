extends Node2D

var local_end_point : Vector2 = Vector2.ZERO

onready var sprite = $Sprite
onready var area = $Area2D
onready var col_node = $Area2D/CollisionShape2D
var col_shape

onready var timer = $Timer
onready var laser_tip = $LaserTip

var disabled : bool = false
const DISABLE_DURATION : float = 4.5

func _ready():
	col_shape = col_node.shape.duplicate(true)
	col_node.shape = col_shape

func _physics_process(dt):
	shoot_raycast()
	position_laser()

func shoot_raycast():
	var space_state = get_world_2d().direct_space_state
	var start = laser_tip.global_position
	var normal = laser_tip.global_transform.x
	var end = start + normal*400.0

	var collision_layer = 2
	var result = space_state.intersect_ray(start, end, [], collision_layer)
	if not result: return

	local_end_point = result.position - start

func position_laser():
	if disabled:
		sprite.set_visible(false)
		return
	
	sprite.set_visible(true)
	sprite.set_position(laser_tip.position)
	
	# make laser so its length is precisely towards the first point it hits
	var length = local_end_point.length()
	var x_scale = length / 64.0
	
	sprite.scale.x = x_scale

	# collision shapes are always centered
	# so resize then move to match the sprite
	area.set_position(sprite.position + Vector2.RIGHT * 0.5 * length)
	col_shape.extents.x = 0.5 * length

func _on_Area2D_body_entered(body):
	if not body.is_in_group("Players"): return
	if disabled: return
	
	# NOTE: important to disable BEFORE slicing, otherwise we ALSO slice the new bodies!
	disabled = true
	col_shape.extents.x = 0
	timer.wait_time = DISABLE_DURATION
	timer.start()
	
	body.get_node("Glue").call_deferred("slice_along_halfway_line")
	body.get_node("Coins").pay_half()

func _on_Timer_timeout():
	disabled = false
