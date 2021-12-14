extends Node2D

const ATTRACT_FORCE : float = 1.45

var active : bool = false
onready var radius : float = $Area2D/CollisionShape2D.shape.radius

onready var area = $Area2D
onready var body = get_parent()

func activate():
	active = true

func deactivate():
	active = false

func _physics_process(dt):
	if not active: return
	
	# TO DO: Use collision layers instead of all this checking for Players?
	for other_body in area.get_overlapping_bodies():
		if other_body == body: continue
		if not other_body.is_in_group("Players"): continue
		
		var vec_to_us = (body.global_position - other_body.global_position)
		var magnitude = radius/vec_to_us.length()
		
		# smaller bodies should be attracted less, as they are more easily moved
		var mass_compensation =  other_body.get_node("Shaper").approximate_radius_as_ratio()
		
		other_body.apply_central_impulse(vec_to_us.normalized() * magnitude * mass_compensation * ATTRACT_FORCE)
