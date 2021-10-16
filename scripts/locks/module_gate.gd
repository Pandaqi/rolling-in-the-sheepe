extends Area2D

var general_parameter

onready var edge : StaticBody2D = get_parent()

func passthrough_allowed(body):
	if edge.type == "coin_gate":
		return (body.get_node("Coins").count() >= general_parameter)

func _on_Area2D_body_entered(body):
	if not body.is_in_group("Players"): return
	if not passthrough_allowed(body): return
	
	for gate in edge.my_room.gates:
		gate.add_collision_exception_with(body)

	if edge.type == "coin_gate":
		body.get_node("Coins").pay(general_parameter)

func _on_Area2D_body_exited(body):
	pass
	
#	if body in col_exceptions:
#		col_exceptions.erase(body)
#		edge.remove_collision_exception_with(body)
