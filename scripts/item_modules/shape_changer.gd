extends Node2D

var key : String

onready var sprite = $Sprite

func _ready():
	var all_keys = GDict.shape_list.keys()
	var rand_elem = randi() % all_keys.size()
	key = all_keys[rand_elem]
	
	sprite.set_frame(GDict.shape_list[key].frame)

func get_shape_key():
	return key
