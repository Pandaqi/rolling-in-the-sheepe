extends Node2D

var active : bool = false
var player_num : int = -1

onready var body = get_parent()

func set_player_num(num):
	player_num = num

func _physics_process(dt):
	if not active: return
	
	for obj in body.contact_data:
		var other_body = obj.body
		
		if not other_body.is_in_group("Players"): continue
		if other_body.get_node("Status").player_num != player_num: continue
		
		glue_object_to_me(obj)
		break

func glue_object_to_me(obj):
	# TO DO
	# 1) Get all shapes in object
	# 2) Convert these to OUR local space
	# 3) Add to object via the "Shaper" module
	pass
