extends RigidBody2D

var teleport_pos : Vector2 = Vector2.ZERO
var teleport_reason : String = ""
var shoot_away_vec : Vector2 = Vector2.ZERO
var contact_data = []
var is_frozen : bool = false

const SHOOT_AWAY_FORCE : float = 4.0

# global nodes
onready var main_node = get_node("/root/Main")

onready var feedback = get_node("/root/Main/Feedback")
onready var player_manager = get_node("/root/Main/PlayerManager")
onready var slicer = get_node("/root/Main/Slicer")
onready var map = get_node("/root/Main/Map")
onready var GUI = get_node("/root/Main/GUI")

# modules => only look them up once here, then use body.<name> in modules
var status
var room_tracker
var shaper
var input
var mover
var clinger
var map_reader
var map_painter
var item_reader
var glue
var face
var rounder
var coins
var edge_reader
var magnet

func _ready():
	physics_material_override = PhysicsMaterial.new()
	
	for child in get_children():
		var conv_name = child.name.to_lower()
		set(conv_name, child)
		
		if not child.script: continue
		if not child.has_method("_module_ready"): continue
		
		child._module_ready()

func has_module(name : String):
	return get(name) and is_instance_valid(get(name))

func _integrate_forces(state):
	var prev_contact_data = contact_data + []
	
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
		
		var first_hit : bool = true
		for c in prev_contact_data:
			if c.body != body_we_hit: continue
			first_hit = false
			break
		
		if first_hit:
			GAudio.play_dynamic_sound(self, "hit")
		
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
	
	var txt = teleport_reason
	if txt == "": 
		txt = "Teleported!"
	else:
		GAudio.play_dynamic_sound({ 'global_position': teleport_pos }, "teleport")
	
	
	feedback.create_at_pos(teleport_pos, txt)
	teleport_pos = Vector2.ZERO

func check_shoot_away(_state):
	if not shoot_away_vec: return
	
	apply_central_impulse(shoot_away_vec * SHOOT_AWAY_FORCE)
	shoot_away_vec = Vector2.ZERO

func plan_teleport(pos, reason : String = ""):
	map.player_progression.on_player_teleported(self)
	teleport_pos = pos
	teleport_reason = reason

func plan_shoot_away(vec):
	shoot_away_vec = vec
