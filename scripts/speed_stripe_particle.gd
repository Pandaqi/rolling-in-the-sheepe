extends Node2D

var my_node

func _on_Timer_timeout():
	self.queue_free()

func attach_node(node):
	my_node = node

func _physics_process(dt):
	if not my_node or not is_instance_valid(my_node): 
		queue_free()
		return
	set_position(my_node.global_position)
	set_rotation((-my_node.get_linear_velocity()).angle())
