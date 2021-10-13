extends Node2D

var glue_active : bool = false
var spikes_active : bool = false
var player_num : int = -1

onready var body = get_parent()

func set_player_num(num):
	player_num = num

func _physics_process(dt):
	check_glue()
	check_spikes()

func check_glue():
	if not glue_active: return
	
	for obj in body.contact_data:
		var other_body = obj.body
		
		if not other_body.is_in_group("Players"): continue
		if other_body.get_node("Status").player_num != player_num: continue
		
		glue_object_to_me(obj)
		break

func check_spikes():
	if not spikes_active: return
	
	for obj in body.contact_data:
		var other_body = obj.body
		
		if not other_body.is_in_group("Players"): continue
		if other_body.get_node("Status").player_num == player_num: continue
		
		spike_object(obj)
		break

func spike_object(obj):
	# TO DO
	# 1) get collision normal
	# 2) Extend to large size (so it goes through the whole other object)
	# 3) Call "Slicer", but restrict to the other body
	pass

func glue_object_to_me(obj):
	# TO DO
	# 1) Get all shapes in object
	# 2) Convert these to OUR local space
	# 3) Add to object via the "Shaper" module
	pass
