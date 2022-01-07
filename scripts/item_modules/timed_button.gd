extends Node

const TIMER_BOUNDS = { 'min': 1.0, 'max': 2.0 }

onready var timer = $Timer
onready var item = get_parent()

func _on_Area2D_body_entered(body):
	var timer_already_running = (timer.time_left > 0)
	if timer_already_running: return
	
	timer.wait_time = rand_range(TIMER_BOUNDS.min, TIMER_BOUNDS.max)
	timer.start()
	
	get_parent().modulate = Color(1,3,1)

func _on_Area2D_body_exited(body):
	if item.area.get_overlapping_bodies().size() > 0: return
	
	timer.stop()
	get_parent().modulate = Color(1,1,1)

func _on_Timer_timeout():
	get_parent().get_lock_module().record_button_push(item)
