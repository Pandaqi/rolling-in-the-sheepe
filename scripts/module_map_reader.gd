extends Node2D

# TO DO: Update this once the generator is NOT the main node anymore
onready var map = get_node("/root/Main")

func _physics_process(dt):
	var cur_cell = map.get_cell_from_node(self)
	
	if cur_cell.terrain == "finish":
		print("WE'VE FINISHED!")

