extends Node

var available_types = []

func _ready():
	available_types = GDict.lock_types.keys()

func get_random_type():
	# DEBUGGING
	return "button_lock"
	return available_types[randi() % available_types.size()]
