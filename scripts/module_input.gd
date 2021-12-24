extends Node

var player_num : int = -1

signal move_right()
signal move_left()

signal move_right_released()
signal move_left_released()

signal double_button()

var reverse : bool = false

var keys_down = {
	'left': false,
	'right': false
}

func get_key(key : String):
	var device_num = GInput.device_order[player_num]
	return key + "_" + str(device_num)

func set_player_num(num : int):
	player_num = num

func _physics_process(_dt):
	if Input.is_action_pressed(get_key("right")):
		if reverse:
			emit_signal("move_left")
		else:
			emit_signal("move_right")
	
	if Input.is_action_pressed(get_key("left")):
		if reverse:
			emit_signal("move_right")
		else:
			emit_signal("move_left")
	
func _input(ev):
	if ev.is_action_pressed(get_key("right")):
		keys_down.right = true
		
	elif ev.is_action_released(get_key("right")):
		keys_down.right = false
		
		emit_signal("move_right_released")
		
		if keys_down.left:
			emit_signal("double_button")
	
	if ev.is_action_pressed(get_key("left")):
		keys_down.left = true

	elif ev.is_action_released(get_key("left")):
		keys_down.left = false
		
		emit_signal("move_left_released")
		
		if keys_down.right:
			emit_signal("double_button")
