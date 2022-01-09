extends Node

onready var my_item = get_parent()
onready var area = my_item.get_area_module().area

onready var player_manager = get_node("/root/Main/PlayerManager")

func _physics_process(dt):
	for body in get_player_bodies(area.get_overlapping_bodies()):
		if player_manager.is_furthest_body(body): continue
		freeze_body(body)

func freeze_body(body):
	body.set_linear_velocity(Vector2.ZERO)
	body.set_angular_velocity(0)

func get_player_bodies(arr):
	var arr2 = []
	for b in arr:
		if not b.is_in_group("Players"): continue
		arr2.append(b)
	return arr2
