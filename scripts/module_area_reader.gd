extends Node2D

const SHOOT_AWAY_FORCE : float = 500.0

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

func get_other_player_bodies():
	var arr = []
	for b in area.get_overlapping_bodies():
		if not b.is_in_group("Players"): continue
		if b.status.player_num == body.status.player_num: continue
		arr.append(b)
	return arr

# TO DO: Is it necessary to go through "plan shoot away"? Can't I just apply the impulse immediately myself?
func blast_away_nearby_bodies():
	for b in get_other_player_bodies():
		var vec_away = (b.global_position - body.global_position).normalized()
		b.plan_shoot_away(vec_away * SHOOT_AWAY_FORCE)

func shrink_nearby_bodies():
	for b in area.get_overlapping_bodies():
		b.rounder.shrink(0.5)
		b.rounder.make_fully_malformed()
