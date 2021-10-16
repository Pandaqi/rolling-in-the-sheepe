extends Node

const MIN_DIST_BETWEEN_PAINTS : float = 15.0

var last_paint_pos : Vector2

onready var mask_painter = get_node("/root/Main/Map/MaskPainter")
onready var body = get_parent()

func _physics_process(_dt):
	for obj in body.contact_data:
		if not (obj.body is TileMap): continue
		if (obj.pos - last_paint_pos).length() < MIN_DIST_BETWEEN_PAINTS: continue
		
		mask_painter.paint_on_mask(obj.pos, body.get_node("Status").player_num)
		last_paint_pos = obj.pos
