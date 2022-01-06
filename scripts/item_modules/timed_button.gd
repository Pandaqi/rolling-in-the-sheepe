extends Node

onready var timer = $Timer

func _on_Area2D_body_entered(body):
	var timer_already_running = (timer.time_left > 0)
	if timer_already_running: return
	
	timer.wait_time = 3.0
	timer.start()

func _on_Area2D_body_exited(body):
	timer.stop()

func _on_Timer_timeout():
	get_parent().get_lock_module().record_button_push(get_parent())
