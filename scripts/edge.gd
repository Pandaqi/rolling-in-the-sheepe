extends StaticBody2D

var type : String
var my_room

var gate_scene = preload("res://scenes/locks/gate.tscn")
var my_gate = null

var soft_locked : bool = false

var col_layers = 1 + 8

func set_type(new_type : String):
	type = new_type
	
	$Sprite.set_frame(GDict.edge_types[type].frame)

func link_to_room(params):
	my_room = params.room
	
	if my_gate: my_gate.queue_free()
	if params.has('gate'):
		make_gate()
		
		var param = params.has('param')
		if not param: param = 0
		
		my_gate.general_parameter = params.param
		my_room.lock.gates.append(self)

func make_gate():
	my_gate = gate_scene.instance()
	add_child(my_gate)

func soft_lock():
	modulate.a = 0.25
	get_node("CollisionShape2D").set_deferred("one_way_collision", true)

func open(sfx : bool = false):
	collision_layer = 0
	collision_mask = 0
	modulate.a = 0.1
	
	if sfx: 
		my_room.main_particles.create_at_pos(self.global_position, "general_powerup", { 'subtype': 'cloud' })
		GAudio.play_dynamic_sound(self, "gate_open")

func close(sfx : bool = false):
	collision_layer = col_layers
	collision_mask = col_layers
	get_node("CollisionShape2D").set_deferred("one_way_collision", false)
	modulate.a = 1.0
	
	if sfx: 
		my_room.main_particles.create_at_pos(self.global_position, "general_powerup", { 'subtype': 'cloud' })
		GAudio.play_dynamic_sound(self, "gate_close")
