extends KinematicBody2D

const SPEED : float = 100.0

func _physics_process(_dt):
	var h = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	var v = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	
	var vec = Vector2(h,v).normalized()
	
	move_and_slide(vec*SPEED)
