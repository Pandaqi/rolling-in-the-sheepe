extends Node

const MIN_DIST_BETWEEN_PAINTS : float = 15.0

var last_paint_pos : Vector2
var disable_paint : bool = false

var last_lock_paint_pos : Vector2 = Vector2.ZERO

onready var body = get_parent()

func _physics_process(_dt):
	# TO DO: What does this do??? Why is it here???
	if disable_paint: 
		disable_paint = false
		return
	
	for obj in body.contact_data:
		if not (obj.body is TileMap): continue
		if (obj.pos - last_paint_pos).length() < MIN_DIST_BETWEEN_PAINTS: continue
		
		body.map.mask_painter.paint_on_mask(obj.pos, body.status.player_num)
		last_paint_pos = obj.pos
