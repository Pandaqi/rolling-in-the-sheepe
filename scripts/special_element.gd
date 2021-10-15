extends Node2D

var type : String = ""

func set_type(tp):
	type = tp
	$Sprite.set_frame(GlobalDict.item_types[tp].frame)
