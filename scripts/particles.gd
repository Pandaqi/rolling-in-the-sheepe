extends Node2D

const BEHIND_PLAYER_PROB : float = 0.66

onready var map = get_node("../Map")

var preloads = {
	'small_puff': preload("res://scenes/particles/small_puff.tscn"),
	'explosion': preload("res://scenes/particles/explosion.tscn")
}

func create_at_pos(pos : Vector2, type : String, params : Dictionary = {}):
	var p = preloads[type].instance()
	p.set_position(pos)
	
	if params.has('match_orientation'):
		p.set_rotation(params.match_orientation.angle())
	
	if randf() <= BEHIND_PLAYER_PROB:
		map.bg_layer.add_child(p)
	else:
		add_child(p)
