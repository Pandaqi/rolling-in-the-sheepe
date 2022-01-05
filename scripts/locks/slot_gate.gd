extends "res://scripts/locks/lock_general.gd"

onready var timer = $Timer

const CLOSE_PROB : float = 0.5
const STOP_CLOSING_GATES_THRESHOLD : int = 13
const TIME_BOUNDS = { 'min': 1.5, 'max': 4.5 }

var num_timer_timeouts = 0
var first_enter : bool = true

# Wait until someone is actually here, before the whole timer thing starts
func on_body_enter(p):
	if not first_enter: return
	
	first_enter = false
	_on_Timer_timeout()

func _on_Timer_timeout():
	restart_timer()
	change_open_gates()
	num_timer_timeouts += 1

func restart_timer():
	timer.wait_time = rand_range(TIME_BOUNDS.min, TIME_BOUNDS.max) + num_timer_timeouts
	timer.start()

func change_open_gates():
	var my_gates = my_room.lock.gates
	if my_gates.size() <= 0: return
	
	var only_open = (num_timer_timeouts > STOP_CLOSING_GATES_THRESHOLD)
	
	for i in range(my_gates.size()):
		var close = randf() <= CLOSE_PROB
		if only_open: close = false
		
		if close:
			my_gates[i].close(true)
		else:
			my_gates[i].open(true)
