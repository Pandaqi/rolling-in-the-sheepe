extends "res://scripts/locks/lock_general.gd"

onready var spawner = $Spawner
onready var label = $Label

# NOTE: This value is quite _low_, as _every body_ must pay it
# 		The value on the "coin sacrifice" is quite high, as only ONE must pay
func _ready():
	general_parameter = randi() % 2 + 1
	gate_type = "coin_gate"

func perform_update():
	general_parameter = max(general_parameter - 1, 1)
	update_label()

func update_label():
	label.perform_update("Pay " + str(general_parameter) + " coins")
