extends Area2D

var general_parameter

onready var edge : StaticBody2D = get_parent()

func passthrough_allowed(body):
	if edge.type == "coin_gate" or edge.type == "sacrifice_coin":
		return (body.coins.count() >= general_parameter)
	
	# these are still GATES (because they change based on conditions)
	# but you can only pass through when they're open anyway, so normally it's always false
	if edge.type == "slot_gate" or edge.type == "fast_gate":
		return false

	return true

func already_paid(body):
	return body in edge.get_collision_exceptions()

func _on_Area2D_body_entered(body):
	if not body.is_in_group("Players"): return
	if not passthrough_allowed(body): return
	if already_paid(body): return
	
	for gate in edge.my_room.lock.gates:
		gate.add_collision_exception_with(body)

	if edge.type == "coin_gate":
		body.coins.pay(general_parameter)
		edge.my_room.lock.perform_update()
	
	elif edge.type == "sacrifice":
		body.glue.call_deferred("slice_along_halfway_line")
		edge.my_room.lock.delete()
	
	elif edge.type == "sacrifice_coin":
		body.coins.pay(general_parameter)
		edge.my_room.lock.delete()

func _on_Area2D_body_exited(_body):
	pass
	
#	if body in col_exceptions:
#		col_exceptions.erase(body)
#		edge.remove_collision_exception_with(body)
