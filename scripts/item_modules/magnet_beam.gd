extends Node

onready var my_item = get_parent()

func _ready():
	turn_area_into_magnet()

func turn_area_into_magnet():
	var area : Area2D = my_item.area
	
	area.space_override = Area2D.SPACE_OVERRIDE_REPLACE_COMBINE
	area.gravity_vec = Vector2.UP
	area.set_position(Vector2.ZERO) # to force an update
	
