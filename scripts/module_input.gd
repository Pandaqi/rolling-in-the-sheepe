extends Node2D

signal move_right()
signal move_left()

signal double_button()

var keys_down = {
	'left': false,
	'right': false
}

func _physics_process(dt):
	if Input.is_action_pressed("ui_right"):
		emit_signal("move_right")
	
	elif Input.is_action_pressed("ui_left"):
		emit_signal("move_left")
	
func _input(ev):
	if ev.is_action_pressed("ui_right"):
		keys_down.right = true
	elif ev.is_action_released("ui_right"):
		keys_down.right = false
		
		if keys_down.left:
			emit_signal("double_button")
	
	if ev.is_action_pressed("ui_left"):
		keys_down.left = true
	elif ev.is_action_released("ui_left"):
		keys_down.left = false
		
		if keys_down.right:
			emit_signal("double_button")
