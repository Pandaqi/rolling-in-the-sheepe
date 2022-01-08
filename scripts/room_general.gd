extends Node2D

const TILE_SIZE : float = 64.0
const ROOM_SIZE : int = 6

var openings = []

func rotate_room(angle):
	var offset_to_center = 0.5*TILE_SIZE*ROOM_SIZE*Vector2(1,1)
	
	$TileMap.position = -offset_to_center
	$Openings.position = -offset_to_center
	
	self.rotate(angle)
	
	$TileMap.position += offset_to_center.rotated(-angle)
	$Openings.position += offset_to_center.rotated(-angle)
	
	generate_openings()

func generate_openings():
	var children = $Openings.get_children()
	for child in children:
		openings.append((child.get_position() / TILE_SIZE).floor())

func fill_all_gaps():
	for opening in openings:
		$TileMap.set_cellv(opening, 0)

func close_opening(side : int, index : int):
	for i in range(openings.size()):
		var opening = openings[i]
		var hit = false
		
		if side == 0 and (opening.x == (ROOM_SIZE - 1) and opening.y == index):
			hit = true
		elif side == 1 and (opening.y == (ROOM_SIZE - 1) and opening.x == index):
			hit = true
		elif side == 2 and (opening.x == 0 and opening.y == index):
			hit = true
		elif side == 3 and (opening.y == 0 and opening.x == index):
			hit = true
		
		if not hit: continue

		openings.remove(i)
		break

func get_openings(side : int):
	var res = []
	for opening in openings:
		var index = -1
		
		if side == 0 and (opening.x == ROOM_SIZE - 1):
			index = opening.y
		elif side == 1 and (opening.y == ROOM_SIZE - 1):
			index = opening.x
		elif side == 2 and (opening.x == 0):
			index = opening.y
		elif side == 3 and (opening.y == 0):
			index = opening.x
		
		if index == -1: continue
		
		res.append(index)
	
	return res
		
