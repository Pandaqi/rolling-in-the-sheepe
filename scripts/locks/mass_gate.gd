extends "res://scripts/locks/lock_general.gd"

onready var label = $Label

func _ready():
	general_parameter = randi() % (GlobalInput.get_player_count() + 2) + 2
	update_label()

func update_label():
	label.perform_update(str(general_parameter) + " shapes")

func on_body_enter(body):
	.on_body_enter(body)
	
	if my_room.players_inside.size() >= general_parameter:
		delete()
