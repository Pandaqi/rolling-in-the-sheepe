extends RigidBody2D

var teleport_pos : Vector2 = Vector2.ZERO

func _integrate_forces(state):
	if not teleport_pos: return
	
	state.transform.origin = teleport_pos
	teleport_pos = Vector2.ZERO

func plan_teleport(pos):
	teleport_pos = pos
