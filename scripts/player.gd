extends RigidBody2D

var teleport_pos : Vector2 = Vector2.ZERO
var contact_data = []

func _ready():
	physics_material_override = PhysicsMaterial.new()

func _integrate_forces(state):
	contact_data = []
	for i in range(state.get_contact_count()):
		contact_data.append({
			'body': state.get_contact_collider_object(i),
			'pos': state.get_contact_local_position(i),
			'normal': state.get_contact_local_normal(i)
		})
	
	if not teleport_pos: return
	
	state.transform.origin = teleport_pos
	teleport_pos = Vector2.ZERO

func plan_teleport(pos):
	teleport_pos = pos
