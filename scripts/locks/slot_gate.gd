extends "res://scripts/locks/lock_general.gd"

onready var timer = $Timer

const TIME_BOUNDS = { 'min': 4, 'max': 10 }
var open_gate = null

var num_timer_timeouts = 0

const STOP_CLOSING_GATES_THRESHOLD : int = 13

func _ready():
	_on_Timer_timeout()

func _on_Timer_timeout():
	restart_timer()
	change_open_gates()
	num_timer_timeouts += 1

func restart_timer():
	timer.wait_time = rand_range(TIME_BOUNDS.min, TIME_BOUNDS.max) + num_timer_timeouts
	timer.start()

func change_open_gates():
	var my_gates = my_room.gates
	if my_gates.size() <= 0: return

	var gate_to_close = open_gate
	if num_timer_timeouts > STOP_CLOSING_GATES_THRESHOLD: gate_to_close = null
	
	var gate_to_open = randi() % my_gates.size()
	
	if gate_to_close: gate_to_close.close()
	
	open_gate = my_gates[gate_to_open]
	open_gate.open()
