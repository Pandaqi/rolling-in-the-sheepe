extends Node2D

const WORLD_SIZE : int = 30
var map = []

var a_star
var route

func _ready():
	randomize()
	a_star = AStar2D.new()
	generate()

# TRICK: The ids ZIGZAG, so we can ensure a zigzagging path by simply
#        picking random ids in ascending order
func get_unique_id(x,y):
	if int(y) % 2 == 0:
		return x + y*WORLD_SIZE
	else:
		return (WORLD_SIZE - 1 - x) + y*WORLD_SIZE

func out_of_bounds(pos):
	return pos.x < 0 or pos.x >= WORLD_SIZE or pos.y < 0 or pos.y >= WORLD_SIZE

func generate():
	map = []
	map.resize(WORLD_SIZE)
	
	# Initialize map array + create object + add point to AStar
	for x in range(WORLD_SIZE):
		map[x] = []
		map[x].resize(WORLD_SIZE)
		
		for y in range(WORLD_SIZE):
			var id = get_unique_id(x,y)
			var pos = Vector2(x,y)
			var rand_val = 1.0 + 100*randf()
			
			map[x][y] = {
				'id': id,
				'pos': pos,
				'astar_val': rand_val
			}
			
			a_star.add_point(id, pos, rand_val)
	
	# Connect all points for AStar (fully, four directions, grid)
	for x in range(WORLD_SIZE):
		for y in range(WORLD_SIZE):
			var pos = Vector2(x,y)
			var id = map[x][y].id
			
			var nbs = [Vector2.RIGHT, Vector2.DOWN]
			
			for nb in nbs:
				var new_pos = pos + nb
				if out_of_bounds(new_pos): continue
				
				var new_id = map[new_pos.x][new_pos.y].id
				a_star.connect_points(id, new_id, true)
	
	# pick random points of interest
	var points_of_interest = []
	var new_poi = 10
	var max_id = (WORLD_SIZE - 1)*(WORLD_SIZE - 1)
	while new_poi < max_id:
		new_poi += 10 + randi() % 15
		points_of_interest.append(new_poi)
	
	points_of_interest.sort()
	
	# Get a random route (starting top left, ending bottom right, through poi)
	route = []
	
	var top_left_id = get_unique_id(0,0)
	var bottom_right_id = get_unique_id(WORLD_SIZE-1, WORLD_SIZE-1)
	
	points_of_interest.push_front(top_left_id)
	points_of_interest.append(bottom_right_id)
	
	var forbid_self_intersection = false
	
	for i in range(points_of_interest.size() - 1):
		var id = points_of_interest[i]
		var next_id = points_of_interest[i+1]
		
		var path = a_star.get_point_path(id, next_id)
		if forbid_self_intersection:
			for p in path:
				var used_id = get_unique_id(p.x, p.y)
				if used_id == next_id: continue
				a_star.remove_point(used_id)
		
		route += Array(path)
	
	# Draw it (for debugging)
	update()

func _draw():
	var col = Color(1,0,0)
	var width = 2
	
	var conv_route = []
	for point in route:
		conv_route.append(point * 10)
	
	draw_polyline(conv_route, col, width)
