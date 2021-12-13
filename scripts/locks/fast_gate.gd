extends "res://scripts/locks/lock_general.gd"

const CLOSED_TIMER = { 'min': 5, 'max': 12 }
const OPEN_TIMER = { 'min': 2, 'max': 5 }

# Options: open or closed
var cur_mode = "open"

onready var timer = $Timer

func _ready():
	change_state()

func _on_Timer_timeout():
	change_state()

func change_state():
	var timer_bounds
	if cur_mode == "open":
		cur_mode = "closed"
		timer_bounds = CLOSED_TIMER
		
		for gate in my_room.gates:
			gate.close()
	
	elif cur_mode == "closed":
		cur_mode = "open"
		timer_bounds = OPEN_TIMER
		
		for gate in my_room.gates:
			gate.open()

	timer.wait_time = rand_range(timer_bounds.min, timer_bounds.max)
	timer.start()
