extends RigidBody2D

var teleport_pos : Vector2 = Vector2.ZERO
var shoot_away_vec : Vector2 = Vector2.ZERO
var contact_data = []
var is_frozen : bool = false

const SHOOT_AWAY_FORCE : float = 4.0

onready var feedback = get_node("/root/Main/Feedback")
onready var map = get_node("/root/Main/Map")

func _ready():
	physics_material_override = PhysicsMaterial.new()

func _integrate_forces(state):
	contact_data = []
	for i in range(state.get_contact_count()):
		var obj = {
			'body': state.get_contact_collider_object(i),
			'pos': state.get_contact_local_position(i),
			'normal': state.get_contact_local_normal(i)
		}
		
		var body_we_hit = obj.body
		if body_we_hit.is_in_group("Players") and body_we_hit.is_frozen:
			body_we_hit.unfreeze()
		
		contact_data.append(obj)
	
	check_shoot_away(state)
	check_teleport(state)

func freeze():
	is_frozen = true
	set_deferred("mode", RigidBody.MODE_STATIC)
	feedback.create_for_node(self, "Freeze!")

func unfreeze():
	is_frozen = false
	set_deferred("mode", RigidBody.MODE_RIGID)
	feedback.create_for_node(self, "Unfreeze!")

func check_teleport(state):
	if not teleport_pos: return
	
	state.transform.origin = teleport_pos
	feedback.create_at_pos(teleport_pos, "Teleported!")
	teleport_pos = Vector2.ZERO

func check_shoot_away(_state):
	if not shoot_away_vec: return
	
	apply_central_impulse(shoot_away_vec * SHOOT_AWAY_FORCE)
	shoot_away_vec = Vector2.ZERO

func plan_teleport(pos):
	map.player_progression.on_player_teleported(self)
	teleport_pos = pos

func plan_shoot_away(vec):
	shoot_away_vec = vec
