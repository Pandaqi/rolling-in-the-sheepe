extends Node2D

onready var map = get_parent()

var available_item_types
var item_types = {
	"spikes": { "frame": 0 }
}

func _ready():
	available_item_types = item_types.keys()

func get_random_type():
	if available_item_types.size() <= 0: return null
	return available_item_types[randi() % available_item_types.size()]

func place(obj):
	var grid_pos = map.get_grid_pos(obj.item.get_global_position())
	map.get_cell(grid_pos).special = obj
	add_child(obj.item)

func erase(obj):
	var grid_pos = map.get_grid_pos(obj.item.get_global_position())

	if not map.get_cell(grid_pos).special: return
	
	obj.item.queue_free()
	map.get_cell(grid_pos).special = null
