extends Node

var inputs = [
	[KEY_RIGHT, KEY_LEFT],
	[KEY_D, KEY_A],
	[KEY_K, KEY_H],
	[KEY_B, KEY_C]
]

var input_order = ["right", "left"]

var devices = {}
var device_order = []

var max_devices = 8

var max_joysticks = 8
var max_keyboard_devices = 4

var num_keyboard_players = 0

func _ready():
	build_input_map()

func create_debugging_players():
	var num_players = 2
	for _i in range(num_players):
		add_new_player('keyboard')
		# add_new_player('controller', i)

#
# Auto-fill the input map with all the right controls
#
func build_input_map():
	var max_keyboard_players = 4
	var max_controller_players = max_joysticks # leave some room for extra connections that might be plugged in, but doing nothing
	
	for i in range(max_keyboard_players):
		
		# movement + rotating
		var id = -(i+1)
		for j in range(input_order.size()):
			var key = input_order[j] + "_" + str(id)
			InputMap.add_action(key)
			
			# KEY
			var ev = InputEventKey.new()
			ev.set_scancode(inputs[i][j])
			InputMap.action_add_event(key, ev)
	
	for i in range(max_controller_players):
		
		# movement + rotating
		for j in range(input_order.size()):
			var key = input_order[j] + "_" + str(i)
			InputMap.add_action(key)
			
			var ev
			
			# CONTROLLER BUTTON (any of them will do)
			# -> 10 are the buttons and shoulder stuff 
			# -> 11 and 12 are start and select
			var create_buttons = (j == 4 or j == 5)
			if create_buttons:
				if j == 4:
					ev = InputEventJoypadButton.new()
					ev.button_index = 0
					ev.set_device(i)
					InputMap.action_add_event(key, ev)
				else:
					ev = InputEventJoypadButton.new()
					ev.button_index = 1
					ev.set_device(i)
					InputMap.action_add_event(key, ev)
				
#				for k in range(10):
#					ev = InputEventJoypadButton.new()
#					ev.button_index = k
#					ev.set_device(i)
#					InputMap.action_add_event(key, ev)
			
			# JOYSTICK MOTION (left and right stick)
			else:
				
				var axes = [JOY_AXIS_0, JOY_AXIS_2]
				if j % 2 == 1: axes = [JOY_AXIS_1, JOY_AXIS_3]
				
				var dir = 1
				if j >= 2: dir = -1
				
				for k in range(axes.size()):
					ev = InputEventJoypadMotion.new()
					ev.set_device(i)
					
					ev.set_axis(axes[k])
					ev.set_axis_value(dir) # <- this one determines if it's positive or negative axis
					
					InputMap.action_add_event(key, ev)
	
	# FOR DEBUGGING
	#printout_inputmap()

func printout_inputmap():
	var ac = InputMap.get_actions()
	for action in ac:
		var input_list = InputMap.get_action_list(action)
		
		for inp in input_list:
			if not (inp is InputEventJoypadMotion): continue
			
			print(inp.as_text())
			print(inp.device)

#
# Handle (un)registering input devices
#
func add_new_player(type, id = -1):
	if max_devices_reached(): return -100
	
	if type == 'keyboard':
		id = get_lowest_id() - 1
		
		if id < -max_keyboard_devices: return -101
	
	if device_already_registered(id): return -102
	
	devices[id] = true
	device_order.append(id)
	
	if type == "keyboard":
		num_keyboard_players += 1
	
	#GlobalAudio.play_static_sound("Success")
	
	return id

func remove_player(type, id, return_num : bool = false):
	if no_devices_registered(): return
	
	if type == 'keyboard' and not id:
		id = get_lowest_id()
	
	if not device_already_registered(id): return

	var index = device_order.find(id)
	
	devices.erase(id)
	device_order.remove(index)
	
	if type == "keyboard":
		num_keyboard_players -= 1
	
	#GlobalAudio.play_static_sound("Fail")
	
	if return_num:
		return index
	else:
		return id

func remove_last_keyboard_player(return_num : bool = false):
	return remove_player("keyboard", null, return_num)

func get_lowest_id():
	var min_id = 0
	for i in range(device_order.size()):
		if device_order[i] < min_id:
			min_id = device_order[i]
	
	return min_id

func no_devices_registered() -> bool:
	return (get_player_count() <= 0)

func max_devices_reached() -> bool:
	return (get_player_count() >= max_devices)

func device_already_registered(id : int) -> bool:
	return devices.has(id)

func get_player_count() -> int:
	return device_order.size()

func has_connected_device(player_num : int) -> bool:
	return player_num < device_order.size()

func get_device_id(player_num : int) -> int:
	return device_order[player_num]

func is_keyboard_player(player_num : int) -> bool:
	return (get_device_id(player_num) < 0)

func get_num_keyboard_players():
	return num_keyboard_players

func get_tutorial_frame_for_player(player_num : int) -> int:
	var id = get_device_id(player_num)
	if id < 0:
		return int(abs(id))
	else:
		return 0
