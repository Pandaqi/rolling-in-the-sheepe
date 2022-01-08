extends Node2D

onready var label = $Label
onready var body = get_parent()

func _physics_process(dt):
	label.global_position = body.global_position + Vector2.UP*30
	label.global_rotation = 0
	
	label.get_node("Label").set_text(str(body.room_tracker.get_cur_room().route.index))
