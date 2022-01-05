extends Node

onready var body = get_parent()

var player_num : int = -1
var shape_name : String = ""
var is_menu : bool = false

var time_penalty : float = 0.0
var has_finished : bool = false

var is_wolf : bool = false

onready var invincibility_timer = $InvincibilityTimer
var is_invincible : bool = false

# Deletes the whole body, but not before (re)setting all sorts of other properties
# that _should_ be properly reset
func delete(part_of_slice : bool = true):
	body.map.player_progression.on_body_removed(body)
	body.player_manager.deregister_body(body)
	
	body.glue.disable_glue()
	body.room_tracker.get_cur_room().entities.remove_player(body)
	body.coins.delete()
	
	if not part_of_slice:
		body.feedback.create_for_node(body, "Destroyed!")
		GAudio.play_dynamic_sound(body, "non_slice_destroy")
	
	body.queue_free()

func set_shape_name(nm : String):
	shape_name = nm

func set_player_num(num : int):
	player_num = num
	
	if body.has_module("input"): body.input.set_player_num(num)
	if body.has_module("glue"): body.glue.set_player_num(num)
	if body.has_module("drawer"): body.drawer.set_color(body.player_manager.player_colors[num])

	body.player_manager.register_body(body)
	
	make_sheep()
	make_invincible()

func modify_time_penalty(val, fb : bool = true):
	time_penalty += val
	
	if fb:
		if val < 0:
			body.feedback.create_for_node(body, "Time bonus!")
		elif val > 0:
			body.feedback.create_for_node(body, "Time penalty!")
	
	if val != 0:
		body.main_particles.create_at_pos(body.global_position, "general_powerup", { 'subtype': 'sandtimer' })
		GAudio.play_dynamic_sound(body, "time")

func make_ghost():
	# this is all just visual polish
	body.feedback.create_for_node(body, "Ghost!")
	GAudio.play_dynamic_sound(body, "ghost")
	body.drawer.play_pop_tween()
	body.main_particles.create_at_pos(body.global_position, "general_powerup", { 'subtype': 'ghost' })
	
	# this actually has a function
	body.collision_layer = 0
	body.collision_mask = 1
	
	body.modulate.a = 0.5

# Layers 1 (2^0; all) and 3 (2^2; players)
func undo_ghost():
	# this is all just visual polish
	body.feedback.create_for_node(body, "Unghosted!")
	GAudio.play_dynamic_sound(body, "ghost")
	body.drawer.play_pop_tween()
	body.main_particles.create_at_pos(body.global_position, "general_powerup", { 'subtype': 'ghost' })
	
	# this actually has a function
	body.collision_layer = 1 + 4
	body.collision_mask = 1 + 4
	
	body.modulate.a = 1.0

func make_wolf():
	if not is_wolf: 
		body.feedback.create_for_node(body, "Wolf!")
		GAudio.play_dynamic_sound(body, "wolf")
		body.drawer.play_pop_tween()
		body.main_particles.create_at_pos(body.global_position, "general_powerup", { 'subtype': 'wolf' })
	
	is_wolf = true
	body.face.make_wolf()
	
	if not is_menu:
		body.glue.make_wolf()
		body.rounder.start_grow_mode("shrink")

func make_sheep():
	if is_wolf: 
		body.feedback.create_for_node(body, "Sheep!")
		GAudio.play_dynamic_sound(body, "sheep")
		body.drawer.play_pop_tween()
		body.main_particles.create_at_pos(body.global_position, "general_powerup", { 'subtype': 'sheep' })
	
	is_wolf = false
	body.face.make_sheep()
	
	if not is_menu:
		body.glue.make_sheep()
		body.rounder.end_grow_mode()

func make_invincible(start_timer = true):
	is_invincible = true
	
	# if we start a timer, it means its an automatic invincibility (which I apply behind the scenes), so don't show feedback
	if start_timer:
		invincibility_timer.start()
	else:
		body.feedback.create_for_node(body, "Invincible!")
		GAudio.play_dynamic_sound(body, "shield_start")
		body.drawer.play_pop_tween()
		body.main_particles.create_at_pos(body.global_position, "general_powerup", { 'subtype': 'shield' })

func make_vincible(from_timer = false):
	if not from_timer: 
		body.feedback.create_for_node(body, "Not invincible!")
		GAudio.play_dynamic_sound(body, "shield_end")
		body.drawer.play_pop_tween()
		body.main_particles.create_at_pos(body.global_position, "general_powerup", { 'subtype': 'shield' })
	
	is_invincible = false

func _on_InvincibilityTimer_timeout():
	make_vincible(true)
