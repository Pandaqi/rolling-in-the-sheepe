extends Node2D

onready var label = $Label
onready var parent = get_parent()

func show():
	label.global_position = parent.rect.get_real_center()
	label.get_node("Label").set_text(str(parent.route.index))
	
	update()

func _draw():
	var outline = parent.outline.get_edges()
	var line_dirs = [Vector2(1,0), Vector2(1,1), Vector2(0,1), Vector2(0,0)]
	for edge in outline:
		var pos = edge.pos * parent.rect.TILE_SIZE
		
		var end_index = (edge.dir_index + 1) % 4
		var offset1 = line_dirs[edge.dir_index] * parent.rect.TILE_SIZE
		var offset2 = line_dirs[end_index] * parent.rect.TILE_SIZE
		draw_line(pos + offset1, pos + offset2, Color(0,0,0), 5)
