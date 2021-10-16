extends StaticBody2D

var type : String
var my_room

var gate_scene = preload("res://scenes/locks/gate.tscn")
var my_gate = null

var edge_types = {
	"regular": { "frame": 0 },
	"coin_gate": { "frame": 1, "gate": true }
}

func set_type(new_type : String):
	type = new_type
	
	$Sprite.set_frame(edge_types[type].frame)
	
	if my_gate: my_gate.queue_free()
	if edge_types[new_type].has('gate'): make_gate()

func make_gate():
	my_gate = gate_scene.instance()
	add_child(my_gate)
