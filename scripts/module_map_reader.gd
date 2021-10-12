extends Node2D

# values between 0-1, set on PhysicsMaterial of body
const ICE_FRICTION : float = 0.0
const BOUNCE_VAL : float = 0.9 

onready var main_node = get_node("/root/Main")
onready var map = get_node("/root/Main/Map")
onready var body = get_parent()

onready var GUI = get_node("/root/Main/GUI")
var player_gui_scene = preload("res://scenes/player_gui.tscn")
var gui

var has_finished : bool = false

var last_cell

func _physics_process(dt):
	position_gui_above_us()
	
	if has_finished: return
	
	read_map()

func read_map():
	var cur_cell = map.get_cell_from_node(self)
	if cur_cell == last_cell: return
	
	undo_effect_of_cell(last_cell)
	do_effect_of_cell(cur_cell)
	
	last_cell = cur_cell

func do_effect_of_cell(cell):
	var terrain = cell.terrain
	var room = map.get_room_at(cell.pos) # can be null??
	
	match terrain:
		"finish":
			finish()
	
		"teleporter":
			room.lock_module.register_player(body)
		
		"reverse_gravity":
			body.get_node("Mover").gravity_dir = -1
		
		"no_gravity":
			body.get_node("Mover").gravity_dir = 0
		
		"ice":
			body.physics_material_override.friction = ICE_FRICTION
		
		"bouncy": 
			body.physics_material_override.bounce = BOUNCE_VAL
		
		"spiderman":
			body.get_node("Mover").clinging_active = true
		
		"speed_boost":
			body.get_node("Mover").speed_multiplier = 2.0
		
		"speed_slowdown":
			body.get_node("Mover").speed_multiplier = 0.5
		
		"glue":
			body.get_node("Glue").active = true
		
		"reverse_controls":
			body.get_node("Input").reverse = true

func undo_effect_of_cell(cell):
	if not cell: return
	
	var terrain = cell.terrain
	var room = map.get_room_at(cell.pos)
	
	match terrain:
		"reverse_gravity":
			body.get_node("Mover").gravity_dir = 1
		
		"no_gravity":
			body.get_node("Mover").gravity_dir = 1
		
		"ice":
			body.physics_material_override.friction = 1.0
		
		"bouncy": 
			body.physics_material_override.bounce = 0.0
		
		"spiderman":
			body.get_node("Mover").clinging_active = false
		
		"speed_boost":
			body.get_node("Mover").speed_multiplier = 1.0
		
		"speed_slowdown":
			body.get_node("Mover").speed_multiplier = 1.0
		
		"glue":
			body.get_node("Glue").active = false
		
		"reverse_controls":
			body.get_node("Input").reverse = false

func finish():
	has_finished = true
	
	var finish_data = main_node.player_finished(body)
	if not finish_data.already_finished: 
		show_gui()
		set_gui_rank(finish_data.rank)
	
	disable_everything()

func has_gui():
	return gui != null

func show_gui():
	gui = player_gui_scene.instance()
	GUI.add_child(gui)

func set_gui_rank(r):
	gui.get_node("Label/Label").set_text("#" + str(r+1))

func position_gui_above_us():
	if not gui: return
	
	var pos = body.get_global_transform_with_canvas().origin
	var offset = Vector2.UP * 50
	
	gui.set_position(pos + offset)

func disable_everything():
	body.collision_layer = 2
	body.collision_mask = 2
	
	body.modulate.a = 0.5

