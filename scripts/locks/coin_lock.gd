extends "res://scripts/locks/lock_general.gd"

var coins_to_grab : int = 5

onready var spawner = $Spawner
onready var label = $Label

func _ready():
	coins_to_grab = 5 + randi() % 3
	spawner.give_feedback()

func perform_update():
	var val = str(spawner.coins_grabbed) + "/" + str(coins_to_grab)
	label.perform_update(val)
	
	check_if_condition_fulfilled()

func check_if_condition_fulfilled():
	if spawner.coins_grabbed < coins_to_grab: return
	
	delete()
