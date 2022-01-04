extends Node

var my_room
var coin_related : bool = false
var general_parameter
var gate_type = ""

onready var map = get_node("/root/Main/Map")
onready var feedback = get_node("/root/Main/Feedback")

signal delete()

func link_to_room(params):
	my_room = params.room
	
	if params.has('coin_related'):
		coin_related = params.coin_related

func on_body_enter(body):
	if coin_related: body.coins.show()

func on_body_exit(body):
	pass

func set_sub_type(tp : String):
	pass

func is_invalid() -> bool:
	return false

func convert_connection_to_gate():
	print("Trying to convert connection to gate")

	if gate_type == "": return
	
	print("What gate?")
	print(gate_type)
	
	var outline = my_room.outline.get_edges()
	for edge in outline:
		var other_side = my_room.outline.edge_links_to(edge)
		if other_side and other_side.route.index > my_room.route.index:
			var edge_body = map.edges.set_at(edge.pos, edge.dir_index, gate_type)
			edge_body.link_to_room({ 'room': my_room, 'param': general_parameter, 'gate': true })
			
			print("An edge was succesfully linked")

# NOTE: Audio system works from nodes, but we want to give it a _position_ for the sound,
# so make a fake object for that
func create_audio_obj():
	return { 'global_position': my_room.rect.get_real_center() }

func on_progress():
	GAudio.play_dynamic_sound(create_audio_obj(), "lock_progress")

func perform_update():
	pass

func delete():
	feedback.create_at_pos(my_room.rect.get_real_center(), "Unlocked!")
	GAudio.play_dynamic_sound(create_audio_obj(), "lock_unlocked")
	
	emit_signal("delete")
	self.queue_free()
	my_room.lock.remove_lock()
