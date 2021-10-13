extends Node2D

var edge_scene = preload("res://scenes/edge.tscn")

onready var map = get_parent()

# TO DO: Actually implement the "set_type" function on edge.gd
func set_at(pos, dir_index, type):
	var already_has_edge = map.get_cell(pos).edges[dir_index]
	if already_has_edge:
		already_has_edge.set_type(type)
		return
	
	var e = edge_scene.instance()
	var vec = map.get_vector_from_dir(dir_index)

	var edge_grid_pos = pos + 0.5*Vector2(1,1) + 0.5*vec
	e.set_position(edge_grid_pos*map.TILE_SIZE)
	e.set_rotation(dir_index * 0.5 * PI)
	e.set_type(type)
	
	map.get_cell(pos).edges[dir_index] = e
	
	add_child(e)
	
	var other_side = vec
	if map.out_of_bounds(pos+other_side): return
	
	var other_dir_index = (dir_index + 2) % 4
	map.get_cell(pos+other_side).edges[other_dir_index] = e

func remove_at(pos, dir_index):
	var other_pos = pos + map.get_vector_from_dir(dir_index)
	var other_dir_index = (dir_index + 2) % 4
	
	if not map.get_cell(pos).edges[dir_index]: return
	
	map.get_cell(pos).edges[dir_index].queue_free()
	map.get_cell(pos).edges[dir_index] = null
	
	if map.out_of_bounds(other_pos): return
	
	map.get_cell(other_pos).edges[other_dir_index].queue_free()
	map.get_cell(other_pos).edges[other_dir_index] = null

func remove_all():
	for x in range(map.WORLD_SIZE.x):
		for y in range(map.WORLD_SIZE.y):
			remove_all_at(Vector2(x,y))

func remove_all_at(pos):
	for i in range(4):
		remove_at(pos, i)
