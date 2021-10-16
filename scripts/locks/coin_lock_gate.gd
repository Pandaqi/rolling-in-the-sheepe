extends "res://scripts/locks/lock_general.gd"

onready var spawner = $Spawner
onready var label = $Label

var gate_type = "coin_gate"
var general_parameter

func _ready():
	general_parameter = randi() % 4 + 1

func convert_connection_to_gate(caller = null):
	.convert_connection_to_gate(self)
	
	label.perform_update("Pay " + str(general_parameter) + " coins")
