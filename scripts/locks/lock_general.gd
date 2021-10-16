extends Node

var my_room

onready var map = get_node("/root/Main/Map")

signal delete()

func convert_connection_to_gate(caller = null):
	if not caller: return
	
	var outline = my_room.outline
	for edge in outline:
		var other_side = my_room.edge_links_to(edge)
		if other_side and other_side.index > my_room.index:
			var edge_body = map.edges.set_at(edge.pos, edge.dir_index, caller.gate_type)
			
			edge_body.my_room = my_room
			edge_body.my_gate.general_parameter = caller.general_parameter
			
			my_room.gates.append(edge_body)

func perform_update():
	pass

func delete():
	emit_signal("delete")
	self.queue_free()
	my_room.remove_lock()
