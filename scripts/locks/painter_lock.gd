extends "res://scripts/locks/lock_general.gd"

const MIN_PERCENTAGE_FILL : float = 0.995
const MIN_CHANGE_BEFORE_FEEDBACK : float = 0.1
const MIN_DIST_BEFORE_AUDIO_FEEDBACK : float = 6.0
const HOLE_SIZE = { 'min': 6, 'max': 24 }

onready var canvas = $Canvas
onready var label = $Label

var surface_image : Image = Image.new()
var surface_texture : ImageTexture = ImageTexture.new()

var paint_image : Image = preload("res://assets/paint_mask.png")

var image_size : Vector2
var resolution : float = 1.0

onready var player_manager = get_node("/root/Main/PlayerManager")

var lowres_grid = []
var grid_resolution : float = 16.0

var start_percentage : float = 0.0
var fill_percentage : float = 0.0

var sub_types = ["regular", "erase", "holes"]
var sub_type : String

func _ready():
	create_mask()
	create_lowres_grid()
	position_canvas()
	
	add_holes()
	
	check_if_condition_fulfilled(true)
	update_canvas_mask()

func add_holes():
	if sub_type != "holes": return
	
	var num_holes = 6
	for i in range(num_holes):
		var rand_pos = my_room.rect.get_random_real_pos_inside({ 'empty': true })
		var rand_local_pos = rand_pos - my_room.rect.get_real_shrunk_pos()
		paint(null, rand_local_pos, 0, true)

# NOTE: always called before _ready()
func set_sub_type(tp : String):
	sub_type = tp
	
	# Holes are the same as erase, but way more precise (don't fill the whole field, just specific parts)
	if sub_type == "holes":
		grid_resolution *= 0.25

func update_label():
	var txt = str(round(fill_percentage*100)) + "/100%"
	label.perform_update(txt)

func create_mask():
	var canvas_size = my_room.rect.get_real_shrunk_size()
	image_size = (canvas_size / resolution).floor()
	surface_image.create(int(image_size.x), int(image_size.y), false, Image.FORMAT_RGBAH)
	
	if sub_type == "erase":
		surface_image.fill(Color(1,1,1,1))

	canvas.texture = surface_texture

func create_lowres_grid():
	lowres_grid = []
	
	var lowres_size = (image_size / grid_resolution).floor()
	lowres_grid.resize(lowres_size.x)
	
	for x in range(lowres_size.x):
		lowres_grid[x] = []
		lowres_grid[x].resize(lowres_size.y)
		for y in range(lowres_size.y):
			var val = false
			var global_pos = get_real_pos_from_lowres(Vector2(x,y))
			var is_filled = my_room.tilemap.is_cell_filled(global_pos)
			if is_filled: val = true
			
			if sub_type == "erase": val = not val
			if sub_type == "holes" and is_filled: val = false
			
			lowres_grid[x][y] = val

func get_real_pos_from_lowres(pos:Vector2) -> Vector2:
	var start = my_room.rect.shrunk.pos
	var integer_res : float = (my_room.rect.TILE_SIZE/grid_resolution)
	var offset = pos/integer_res
	
	return (start + offset).floor()

func position_canvas():
	canvas.set_position(my_room.rect.get_real_shrunk_pos())

func _physics_process(dt):
	var res = make_entities_paint()
	if not res: return
	
	update_canvas_mask()
	
	var done = check_if_condition_fulfilled()
	if done: delete()

func make_entities_paint():
	var did_something = false
	for entity in my_room.entities.get_them():
		var global_pos = entity.global_position
		var local_pos = global_pos - canvas.get_position()
		
		var player_num = entity.status.player_num
		
		paint(entity, local_pos, player_num)
		did_something = true
	
	return did_something

func check_if_condition_fulfilled(first_check : bool = false):
	var old_fill_percentage = fill_percentage
	
	fill_percentage = 0.0
	for x in range(lowres_grid.size()):
		for y in range(lowres_grid[0].size()):
			if lowres_grid[x][y]: 
				fill_percentage += 1.0
	
	fill_percentage /= float(lowres_grid.size() * lowres_grid[0].size())
	if first_check: start_percentage = fill_percentage
	
	if sub_type == "holes":
		fill_percentage *= (1.0 / start_percentage)
	
	update_label()
	
	var success = fill_percentage >= MIN_PERCENTAGE_FILL
	if sub_type == "erase" or sub_type == "holes": success = (fill_percentage < (1.0 - MIN_PERCENTAGE_FILL))
	
	if abs(old_fill_percentage - fill_percentage) > MIN_CHANGE_BEFORE_FEEDBACK:
		on_progress()
	
	return success

func update_canvas_mask():
	surface_texture.create_from_image(surface_image)

func paint(entity, pos : Vector2, p_num : int, force_paint : bool = false):
	surface_image.lock()

	var radius = floor(rand_range(HOLE_SIZE.min, HOLE_SIZE.max+1))
	if entity: radius = entity.shaper.approximate_radius()
	
	var col = player_manager.player_colors[p_num]
	
	if sub_type == "erase" or sub_type == "holes":
		col.a = 0.0
	
	if force_paint:
		col = Color(0,0,0,1)
	
	for x in range(-radius,radius):
		for y in range(-radius,radius):
			if Vector2(x,y).length() > radius: continue
			
			var temp_pos = pos + Vector2(x,y)
			if out_of_mask_bounds(temp_pos): continue
			
			var global_pos = (temp_pos + my_room.rect.shrunk.pos).floor()
			if sub_type == "holes" and cannot_fill_cell(global_pos): continue
			
			surface_image.set_pixelv(temp_pos, col)
			
			var floored_pos = (temp_pos / grid_resolution).floor()
			var val = true
			if not force_paint:
				if sub_type == "erase" or sub_type == "holes": val = false
			lowres_grid[floored_pos.x][floored_pos.y] = val
	
	surface_image.unlock()
	
	# the only reason we keep track of last position and check all this
	# is to prevent spawning audio feedback every goddamn frame we're painting
	if (entity.get_global_position() - entity.map_painter.last_lock_paint_pos).length() > MIN_DIST_BEFORE_AUDIO_FEEDBACK:
		GAudio.play_dynamic_sound(entity, "paint")
		entity.map_painter.last_lock_paint_pos = entity.get_global_position()

func out_of_mask_bounds(pos):
	return pos.x < 0 or pos.x >= image_size.x or pos.y < 0 or pos.y >= image_size.y

func cannot_fill_cell(global_pos):
	return my_room.tilemap.is_cell_filled(global_pos)
