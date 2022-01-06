extends Node

const TIMEOUT_DURATION : float = 1.0
const MIN_VELOCITY_FOR_BOMB : float = 180.0

const SPEED_ITEM_FORCE : float = 50.0
const SLOWDOWN_ITEM_FORCE : float = 25.0
const TRAMPOLINE_FORCE : float = 800.0

# less time = better, so a time bonus is a negative number
const TIME_BONUS_VAL : float = -15.0
const TIME_PENALTY_VAL : float = 5.0

onready var body = get_parent()
onready var timeout_timer = $TimeoutTimer

var toggled_items = []
var immediate_items = []

var we_are_bomb : bool = false
var on_timeout : bool = false

func _physics_process(_dt):
	if body.status.is_invincible: return
	
	for obj in toggled_items:
		execute_toggled_item(obj)
	
	reset_immediate_items()
	for obj in body.contact_data:
		if not (obj.body is TileMap): continue
		register_contact(obj)
	
	do_something_with_items()

func register_contact(obj):
	var map = body.map
	var safety_margin = 0.5*obj.normal*map.TILE_SIZE
	var grid_pos = map.get_grid_pos(obj.pos - safety_margin)
	if map.out_of_bounds(grid_pos): return
	
	var cell = map.get_cell(grid_pos)
	if we_are_bomb and body.mover.velocity_last_frame.length() > MIN_VELOCITY_FOR_BOMB:
		map.explode_cell(body, grid_pos)
		return
	
	if not cell.special: return
	
	var type = cell.special.type
	if not map.special_elements.type_is_immediate(type): return
	
	var reject_by_invincibility = (body.status.is_invincible and GDict.item_types[type].has('invincibility'))
	if reject_by_invincibility: return
	
	var already_registered_cell = false
	for item in immediate_items:
		if (item.pos - grid_pos).length() <= 0.3:
			already_registered_cell = true
			break
	
	if already_registered_cell: return

	var coming_from_wrong_side = false
	var item_rot = cell.special.rotation
	var item_vec = Vector2(cos(item_rot), sin(item_rot))
	var our_vec = (body.get_global_position() - obj.pos).normalized()
	coming_from_wrong_side = our_vec.dot(item_vec) <= 0
	
	if coming_from_wrong_side: return
	
	var better_obj = {
		'pos': grid_pos,
		'type': type,
		'item': cell.special,
		'col_data': obj
	}
	
	immediate_items.append(better_obj)

#
# Toggled items
# (when inside area, they toggle on, when outside, they toggle off again)
#
func turn_on_item(block, tp : String):
	print("TRYING TO TURN ON")
	print(tp)
	
	if not body.map.special_elements.type_is_toggle(tp): return
	
	var obj = { 'block': block, 'type': tp }
	toggled_items.append(obj)
	
	print("TURNING ON")
	print(tp)
	
	match tp:
		'ghost': body.status.make_ghost()
		'shield': body.status.make_invincible(false)
		'rounder': body.rounder.enable_fast_mode('round')
		'sharper': body.rounder.enable_fast_mode('sharp')
		'ice': body.map_reader.do_ice()
		'spiderman': body.map_reader.do_spiderman()
		'glue': body.map_reader.do_glue()
		'speedup': 
			body.main_particles.create_for_node(body, "speed_stripes", { "match_orientation": -get_move_dir_along_block(block), "place_behind": true })
			GAudio.play_dynamic_sound(body, "speedup")
		'slowdown': 
			body.main_particles.create_for_node(body, "speed_stripes", { "match_orientation": -get_move_dir_along_block(block), "place_behind": true })
			GAudio.play_dynamic_sound(body, "slowdown")

func turn_off_item(_block, tp : String):
	if not body.map.special_elements.type_is_toggle(tp): return
	
	match tp:
		'ghost': body.status.undo_ghost()
		'shield': body.status.make_vincible(false)
		'rounder': body.rounder.disable_fast_mode()
		'sharper': body.rounder.disable_fast_mode()
		'ice': body.map_reader.undo_ice()
		'spiderman': body.map_reader.undo_spiderman()
		'glue': body.map_reader.undo_glue()
	
	for obj in toggled_items:
		if obj.type != tp: continue
		toggled_items.erase(obj)

func get_move_dir_along_block(block):
	# get normal + which direction player is going (the most)
	var rot = block.rotation
	var normal = Vector2(cos(rot), sin(rot))
	var norm_vel = body.get_linear_velocity().normalized()
	
	var dotA = normal.rotated(0.5*PI).dot(norm_vel)
	var dotB = normal.rotated(-0.5*PI).dot(norm_vel)
	
	var move_dir = normal.rotated(0.5*PI)
	if dotB > dotA: move_dir *= -1
	
	return move_dir

func execute_toggled_item(obj):
	var type = obj.type
	
	var move_dir = get_move_dir_along_block(obj.block)
	
	match type:
		'speedup':
			body.apply_central_impulse(move_dir * SPEED_ITEM_FORCE)
		
		'slowdown':
			body.apply_central_impulse(-move_dir * SLOWDOWN_ITEM_FORCE)

#
# Immediate items
# (these are triggered every frame you touch them, immediately, and then reset at the end of the frame)
#
func do_something_with_items():
	if on_timeout: return
	
	var did_something = false
	for obj in immediate_items:
		handle_item(obj)
		did_something = true
	
	if did_something:
		timeout()

func handle_item(obj):
	var type = obj.type
	var prevent_deletion = false
	
	match type:
		"spikes":
			var slice_line = body.glue.get_realistic_slice_line(obj.col_data)
			body.slicer.slice_bodies_hitting_line(slice_line.start, slice_line.end, [body])
		
		"button_regular":
			obj.item.my_room.lock.record_button_push(obj.item) 
		
		"button_order":
			var res = obj.item.my_room.lock.record_button_push(obj.item)
			if not res: prevent_deletion = true
		
		"trampoline":
			var normal = obj.item.transform.x
			GAudio.play_dynamic_sound(body, "jump")
			body.main_particles.create_for_node(body, "speed_stripes", { "match_orientation": -normal, "place_behind": true })
			body.apply_central_impulse(normal * TRAMPOLINE_FORCE)
		
		"breakable":
			body.map.explode_cell(body, obj.pos)
		
		"reset_shape":
			body.shaper.reset_to_starting_shape()
		
		"change_shape":
			# TO DO: This resets to original size; rescale to roughly match the new size?
			var shape_key = obj.item.my_module.get_shape_key()
			body.shaper.create_new_from_shape_key(shape_key)
		
		"coin":
			body.coins.get_paid(1)
		
		"freeze":
			body.freeze()
		
		"time_bonus":
			body.status.modify_time_penalty(TIME_BONUS_VAL)
		
		"time_penalty":
			body.status.modify_time_penalty(TIME_PENALTY_VAL)
		
		"fast_forward":
			var p = body.map.player_progression.get_leading_player()
			body.plan_teleport(p.global_position, "To the front!")
		
		"fast_backward":
			var p = body.map.player_progression.get_trailing_player()
			body.plan_teleport(p.global_position, "To the back!")
	
	if prevent_deletion: return
	
	body.map.special_elements.delete_on_activation(obj.item)

func timeout():
	on_timeout = true
	timeout_timer.wait_time = TIMEOUT_DURATION
	timeout_timer.start()

func _on_TimeoutTimer_timeout():
	on_timeout = false

func reset_immediate_items():
	immediate_items = []

func make_bomb():
	we_are_bomb = true

func undo_bomb():
	we_are_bomb = false
