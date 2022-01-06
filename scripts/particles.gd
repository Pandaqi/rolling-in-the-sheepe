extends Node2D

const BEHIND_PLAYER_PROB : float = 0.66

onready var map = get_node("../Map")

var preloads = {
	'small_puff': preload("res://scenes/particles/small_puff.tscn"),
	'explosion': preload("res://scenes/particles/explosion.tscn"),
	'general_powerup': preload("res://scenes/particles/general_powerup.tscn"),
	"speed_stripes": preload("res://scenes/particles/speed_stripes.tscn"),
	"float": preload("res://scenes/particles/float.tscn"),
	"lock": preload("res://scenes/particles/lock.tscn")
}

func create_for_node(node, type : String, params : Dictionary = {}):
	params.node = node
	create_at_pos(node.global_position, type, params)

func create_at_pos(pos : Vector2, type : String, params : Dictionary = {}):
	var p = preloads[type].instance()
	p.set_position(pos)
	
	if params.has('match_orientation'):
		p.set_rotation(params.match_orientation.angle())
	
	var place_behind = (randf() <= BEHIND_PLAYER_PROB) or (params.has("place_behind") and not params.has("place_front"))
	
	if params.has('subtype'):
		var texture_key = "res://assets/particles/particle_" + params.subtype + ".png"
		p.get_node("Particles2D").texture = load(texture_key)
	
	if type == "speed_stripes" and params.has('node'):
		p.attach_node(params.node)
	
	if params.has('spread_across'):
		var room = params.spread_across
		var extents_2d = 0.5*room.rect.get_real_size()
		var extents = Vector3(extents_2d.x, extents_2d.y, 0)
		p.get_node("Particles2D").process_material.emission_box_extents = extents 
	
	if place_behind:
		map.bg_layer.add_child(p)
	else:
		add_child(p)
	
	
