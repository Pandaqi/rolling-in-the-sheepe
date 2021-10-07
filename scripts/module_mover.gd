extends Node2D

const IMPULSE_STRENGTH : float = 200.0

func _on_Input_move_left():
	get_parent().apply_torque_impulse(-IMPULSE_STRENGTH)

func _on_Input_move_right():
	get_parent().apply_torque_impulse(IMPULSE_STRENGTH)
