extends Node2D

signal move_right()
signal move_left()

func _physics_process(dt):
	if Input.is_action_pressed("ui_right"):
		emit_signal("move_right")
	
	elif Input.is_action_pressed("ui_left"):
		emit_signal("move_left")
