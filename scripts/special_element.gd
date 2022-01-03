extends Node2D

var type : String = ""
var general_parameter
var my_room = null
var my_module = null

onready var label = $Label
onready var area = $Area2D

func set_general_parameter(val):
	general_parameter = val
	label.get_node("Label").set_text(str(general_parameter+1))

func set_type(tp):
	if my_module: my_module.queue_free()
	
	type = tp
	
	var data = GDict.item_types[tp]
	
	$Sprite.set_frame(data.frame)
	
	if data.has("needs_label"):
		label.set_visible(true)
		label.set_rotation(-rotation)
	else:
		label.set_visible(false)
	
	if data.has('module'):
		my_module = load("res://scenes/item_modules/" + type + ".tscn").instance()
		
		if my_module.has_method("_on_Area2D_body_entered"):
			area.connect("body_entered", my_module, "_on_Area2D_body_entered")
		
		if my_module.has_method("_on_Area2D_body_exited"):
			area.connect("body_exited", my_module, "_on_Area2D_body_exited")
		
		add_child(my_module)
		
		print("ADDED MODULE")

func has_overlapping_bodies():
	return area.get_overlapping_bodies().size()

func get_lock_module():
	return my_room.lock.lock_module

func _on_Area2D_body_entered(body):
	if not body.is_in_group("Players"): return
	body.item_reader.turn_on_item(self, type)

func _on_Area2D_body_exited(body):
	if not body.is_in_group("Players"): return
	body.item_reader.turn_off_item(self, type)
