extends Node2D

var type : String = ""
var general_parameter
var my_room = null
var my_module = null
var data

onready var label = $Label

var area = null
var beam_scene = preload("res://scenes/item_modules/beam_area.tscn")
var regular_area_scene = preload("res://scenes/item_modules/regular_area.tscn")

func set_general_parameter(val):
	general_parameter = val
	label.get_node("Label").set_text(str(general_parameter+1))

func get_data():
	return data

# TO DO: It seems as if "set_type" is called multiple times on elements?
func set_type(tp):
	print("SET ELEMENT")
	print(self.name)
	print(tp)
	
	if my_module: my_module.queue_free()
	if area: area.get_parent().queue_free()
	
	type = tp
	
	data = GDict.item_types[tp]
	
	if data.has('beam'):
		var b = beam_scene.instance()
		add_child(b)
		
		area = b.get_node("Area2D")
		
		print("BEAM SCENE ADDED")
		
		if data.has('unit_beam'):
			b.set_max_tile_dist(1)
	else:
		var a = regular_area_scene.instance()
		add_child(a)
		
		area = a.get_node("Area2D")
	
	area.connect("body_entered", self, "_on_Area2D_body_entered")
	area.connect("body_exited", self, "_on_Area2D_body_exited")
	
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

func has_overlapping_bodies():
	return area.get_overlapping_bodies().size()

func get_area_module():
	return area.get_parent()

func get_lock_module():
	return my_room.lock.lock_module

func _on_Area2D_body_entered(body):
	if not body.is_in_group("Players"): return
	body.item_reader.turn_on_item(self, type)

func _on_Area2D_body_exited(body):
	if not body.is_in_group("Players"): return
	body.item_reader.turn_off_item(self, type)
