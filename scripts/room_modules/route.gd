extends Node

var prev_room
var dir : int
var index : int

var num_tiles_before_us : int

onready var parent = get_parent()

func set_index(i):
	index = i
	parent.debugger.show()

func is_first_room():
	return index <= 0

func set_dir(d):
	dir = d

func set_path_position(num):
	num_tiles_before_us = num

func tiled_dist_to(other_room):
	return (other_room.route.num_tiles_before_us - num_tiles_before_us)

func set_previous_room(r):
	prev_room = r

func get_previous_room():
	return prev_room

func has_previous_room():
	return (prev_room != null)
