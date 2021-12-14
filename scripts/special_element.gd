extends Node2D

var type : String = ""
var general_parameter
var my_room

onready var label = $Label
onready var area = $Area2D
onready var timer = $Timer

func set_general_parameter(val):
	general_parameter = val
	label.get_node("Label").set_text(str(general_parameter+1))

func set_type(tp):
	type = tp
	
	var data = GlobalDict.item_types[tp]
	
	$Sprite.set_frame(data.frame)
	
	if data.has("needs_label"):
		label.set_visible(true)
		label.set_rotation(-rotation)
	else:
		label.set_visible(false)

func _on_Area2D_body_entered(body):
	if type != "button_timed": return
	
	var timer_already_running = (timer.time_left > 0)
	if timer_already_running: return
	
	timer.wait_time = 3.0
	timer.start()

func _on_Area2D_body_exited(body):
	if type != "button_timed": return
	
	timer.stop()

func has_overlapping_bodies():
	return area.get_overlapping_bodies().size()

func _on_Timer_timeout():
	if type == "button_timed":
		my_room.lock.lock_module.record_button_push(self)
