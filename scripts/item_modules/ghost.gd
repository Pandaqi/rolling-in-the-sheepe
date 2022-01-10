extends Node

onready var my_item = get_parent()

func _ready():
	my_item.area.collision_layer = 1 + 4 # layer 1, layer 3
