extends Node2D

onready var my_lock = get_parent()

func _ready():
	position_label()

func position_label():
	set_position(my_lock.my_room.rect.get_free_real_pos_inside())

func perform_update(val):
	get_node("Label").set_text(val)
