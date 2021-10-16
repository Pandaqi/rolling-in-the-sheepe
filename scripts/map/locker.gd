extends Node

var available_types = []

func _ready():
	available_types = GlobalDict.lock_types.keys()

func get_random_type():
	return available_types[randi() % available_types.size()]
