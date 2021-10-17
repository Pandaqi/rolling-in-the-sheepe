extends "res://scripts/locks/lock_general.gd"

onready var label = $Label

func _ready():
	gate_type = "sacrifice_coin"
	general_parameter = randi() % 5 + 4
	update_label()

func update_label():
	label.perform_update("Pay " + str(general_parameter))
