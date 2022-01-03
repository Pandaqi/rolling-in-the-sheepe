extends Node2D

const OFFSET : Vector2 = Vector2.UP*32
var fb_scene = preload("res://scenes/ui/feedback.tscn")

func create_at_pos(pos, txt):
	var f = fb_scene.instance()
	f.get_node("Container/Label").set_text(str(txt))
	f.set_position(pos + OFFSET)
	add_child(f)

func create_for_node(node, txt):
	create_at_pos(node.global_position, txt)

