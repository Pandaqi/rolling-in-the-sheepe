extends Node

var edge_scene = preload("res://scenes/edge.tscn")

onready var map = get_parent()

func handle_gates(room):
	if not room: return
	
	room.lock.recalculate_gates()

func set_at(pos, dir_index, type):
	# if the edge already exists, just change its type
	# (otherwise we get duplicates, and I'd need to remove shit beforehand, it's all bad)
	var already_has_edge = map.get_cell(pos).edges[dir_index]
	if already_has_edge:
		already_has_edge.set_type(type)
		
		var other_side = map.get_vector_from_dir(dir_index)
		if not map.out_of_bounds(pos+other_side):
			var other_dir_index = (dir_index + 2) % 4
			map.get_cell(pos+other_side).edges[other_dir_index].set_type(type)
		
		return already_has_edge
	
	var e = edge_scene.instance()
	var vec = map.get_vector_from_dir(dir_index)

	var half_size = 0.5*16 / map.TILE_SIZE
	var edge_grid_pos = pos + 0.5*Vector2(1,1) + (0.5 + half_size)*vec
	e.set_position(edge_grid_pos*map.TILE_SIZE)
	e.set_rotation(dir_index * 0.5 * PI)
	e.set_type(type)
	
	map.get_cell(pos).edges[dir_index] = e
	
	add_child(e)
	
	var other_side = vec
	if map.out_of_bounds(pos+other_side): return e
	
	var other_dir_index = (dir_index + 2) % 4
	map.get_cell(pos+other_side).edges[other_dir_index] = e
	
	return e

func remove_at(pos, dir_index, soft_remove : bool = false):
	var other_pos = pos + map.get_vector_from_dir(dir_index)
	var other_dir_index = (dir_index + 2) % 4
	
	var e1 = map.get_cell(pos).edges[dir_index]
	if not e1: return
	
	if soft_remove:
		e1.soft_lock()
	else:
		e1.queue_free()
		map.get_cell(pos).edges[dir_index] = null
	
	if map.out_of_bounds(other_pos): return
	
	var e2 = map.get_cell(other_pos).edges[other_dir_index]
	
	if soft_remove:
		e2.soft_lock()
	else:
		e2.queue_free()
		map.get_cell(other_pos).edges[other_dir_index] = null

func remove_all():
	for x in range(map.WORLD_SIZE.x):
		for y in range(map.WORLD_SIZE.y):
			remove_all_at(Vector2(x,y))

func remove_all_at(pos):
	for i in range(4):
		remove_at(pos, i)
