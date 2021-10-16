extends Node

onready var body = get_parent()

# NOOOO, needs to switch to a "body entered, body exit" strategy
# (because we don't want to recheck the condition, or re-pay money, while we're moving through the gate itself)
func _physics_process(_dt):
	for obj in body.contact_data:
		if not obj.body.is_in_group("Edges"): continue

		hitting_edge
