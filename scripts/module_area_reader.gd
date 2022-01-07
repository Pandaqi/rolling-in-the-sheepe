extends Node2D

onready var body = get_parent()
onready var area = $Area2D

func _on_Area2D_body_entered(other_body):
	handle_body(other_body)

func _on_Area2D_body_exited(other_body):
	pass # Replace with function body.

func recheck_existing_bodies():
	print(area.get_overlapping_bodies())
	for b in area.get_overlapping_bodies():
		var its_us = b == body
		if its_us: return
		
		print("BODY")
		print(b)
		handle_body(b)

func handle_body(b):
	if body.glue.glue_active and body.glue.use_glue_area:
		print("TRYING TO GLUE")
		body.glue.glue_if_valid(b)

func _on_Area2D_area_entered(other_area):
	if not other_area.get_parent().is_in_group("SpecialTiles"): return
	if other_area.get_parent().get_data().has("coin_related"):
		body.coins.show()

func _on_Area2D_area_exited(other_area):
	pass # Replace with function body.
