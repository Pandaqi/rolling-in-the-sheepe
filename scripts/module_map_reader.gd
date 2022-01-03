extends Node

# values between 0-1, set on PhysicsMaterial of body
const ICE_FRICTION : float = 0.1
const BOUNCE_VAL : float = 0.8

# used when repelling people from a "body_limit" terrain
const REPEL_FORCE : float = 600.0
const MIN_COIN_LIMIT : int = 4

const MAX_TILED_DIST_BETWEEN_PLAYERS : int = 50
const MIN_EUCLIDIAN_DIST_BEFORE_TELEPORT : float = 460.0
const MAX_EUCLIDIAN_DIST_GUARANTEE_TELEPORT : float = 1500.0

const TIME_PENALTY_TOO_FAR_BEHIND : float = 10.0

onready var body = get_parent()

var player_gui_scene = preload("res://scenes/player_gui.tscn")
var gui

var has_finished : bool = false

# a "fake object" to ensure we don't need any checks at the start if last_cell exists yet
# TO DO => might also implement this in other locations
var last_cell = { 'terrain': null, 'pos': Vector2.ZERO, 'room': null }
var last_move_dir : Vector2

func _physics_process(_dt):
	position_gui_above_us()
	
	if has_finished: return
	
	read_map()
	check_if_too_far_behind()

func read_map():
	var cur_cell = body.map.get_cell_from_node(body)
	if cur_cell == last_cell: return
	if cur_cell.terrain == last_cell.terrain: return
	
	last_move_dir = (cur_cell.pos - last_cell.pos).normalized()
	
	undo_effect_of_cell(last_cell)
	do_effect_of_cell(cur_cell)
	
	last_cell = cur_cell

func do_effect_of_cell(cell):
	var terrain = cell.terrain
	if not terrain: return
	
	body.map.terrain.someone_entered(body, terrain)
	
	# TO DO: not necessarily correct; might take a frame to update
	# better to use => cell.room?
	var room = body.room_tracker.get_cur_room()
	
	match terrain:
		"finish":
			finish()
	
		"teleporter":
			room = body.room_tracker.get_room_after_forced_update()
			room.lock_module.register_player(body)
		
		"reverse_gravity":
			body.mover.gravity_dir = -1
		
		"no_gravity":
			body.mover.gravity_dir = 0
		
		"ice":
			do_ice()
		
		"bouncy": 
			body.physics_material_override.bounce = BOUNCE_VAL
		
		"spiderman":
			do_spiderman()
		
		"speed_boost":
			body.mover.speed_multiplier = 2.0
		
		"speed_slowdown":
			body.mover.speed_multiplier = 0.5
		
		"glue":
			do_glue()
		
		"reverse_controls":
			body.feedback.create_for_node(body, "Reversed Controls!")
			body.input.reverse = true
		
		"spikes":
			body.glue.spikes_active = true
		
		"ghost":
			body.status.make_ghost()
		
		"grower":
			body.rounder.grow_instead_of_rounding = true
		
		"no_wolf":
			body.map.player_progression.disable_wolf()
		
		"body_limit":
			# NOTE: at this point we've already added ourself to the room, so its "size before" is 1 smaller than it is now
			var body_max = GInput.get_player_count()
			var body_count = (cell.room.entities.count() - 1)
			
			if body_count >= body_max:
				body.set_linear_velocity(Vector2.ZERO)
				body.apply_central_impulse(-last_move_dir*REPEL_FORCE)
		
		"invincibility":
			if body.coins.count() >= MIN_COIN_LIMIT:
				body.status.make_invincible(false) # start no timer, so invincibility is "permanent" while in terrain
		
		"rounder":
			if body.coins.count() >= MIN_COIN_LIMIT:
				body.rounder.make_fully_round()
			else:
				body.rounder.make_fully_malformed()
		
		"halver":
			body.coins.pay_half()
		
		"slower":
			body.mover.speed_multiplier = clamp(body.coins.as_ratio()*2.0, 0.5, 2.0) 
		
		"bomb":
			body.item_reader.make_bomb()
		
		"reverse_rounding":
			body.rounder.reverse_rounding = true
		
		"magnet":
			body.magnet.activate()
		
		"body_cleanup":
			body.player_manager.remove_furthest_body_of(body.status.player_num)

func undo_effect_of_cell(cell):
	if not cell: return
	
	var terrain = cell.terrain
	if not terrain: return
	
	body.map.terrain.someone_exited(body, terrain)
	var room = body.map.get_room_at(cell.pos)
	
	match terrain:
		"teleporter":
			room.lock_module.deregister_player(body)
		
		"reverse_gravity":
			body.mover.gravity_dir = 1
		
		"no_gravity":
			body.mover.gravity_dir = 1
		
		"ice":
			undo_ice()
		
		"bouncy": 
			body.physics_material_override.bounce = 0.0
		
		"spiderman":
			undo_spiderman()
		
		"speed_boost":
			body.mover.speed_multiplier = 1.0
		
		"speed_slowdown":
			body.mover.speed_multiplier = 1.0
		
		"glue":
			undo_glue()
		
		"reverse_controls":
			body.feedback.create_for_node(body, "Normal Controls!")
			body.input.reverse = false
		
		"spikes":
			body.glue.spikes_active = false
		
		"ghost":
			body.status.undo_ghost()
		
		"grower":
			body.rounder.grow_instead_of_rounding = false
		
		"no_wolf":
			body.map.player_progression.enable_wolf()
		
		"invincibility":
			body.status.make_vincible()
		
		"slower":
			body.mover.speed_multiplier = 1.0
		
		"bomb":
			body.item_reader.undo_bomb()
		
		"reverse_rounding":
			body.rounder.reverse_rounding = false
		
		"magnet":
			body.magnet.deactivate()

#
# Specific do/undos, so I can re-use them in the item_reader
#
func do_ice():
	body.physics_material_override.friction = ICE_FRICTION

func undo_ice():
	body.physics_material_override.friction = 1.0

func do_spiderman():
	body.clinger.active = true

func undo_spiderman():
	body.clinger.active = false

func do_glue():
	body.glue.glue_active = true

func undo_glue():
	body.glue.glue_active = false

#
# Misc
#
func finish():
	has_finished = true
	
	body.status.has_finished = true
	body.status.make_ghost()
	
	if GDict.cfg.reset_players_to_start_shape_at_finish:
		body.shaper.reset_to_starting_shape()
	
	var finish_data = body.main_node.player_finished(body)
	show_gui()
	set_gui_rank(finish_data.rank)

func has_gui():
	return gui != null

func show_gui():
	gui = player_gui_scene.instance()
	body.GUI.add_child(gui)

func set_gui_rank(r):
	gui.get_node("Label/Label").set_text("#" + str(r+1))

func position_gui_above_us():
	if not gui: return
	
	var pos = body.get_global_transform_with_canvas().origin
	var offset = Vector2.UP * 50
	
	gui.set_position(pos + offset)

func check_if_too_far_behind():
	if body.map.player_progression.get_leading_player() == self: return
	
	var too_far_behind = false
	#var my_room = body.room_tracker.get_cur_room()
	
	var next_player = body.map.route_generator.get_next_best_player(body)
	if not next_player: return
	
	var next_player_room = next_player.room_tracker.get_cur_room()
	
	# if we're still perfectly in view (because very close to next best player)
	# ignore this whole thing, we don't (yet) need to teleport
	var euclidian_dist = (next_player.get_global_position() - body.get_global_position()).length()
	if euclidian_dist <= MIN_EUCLIDIAN_DIST_BEFORE_TELEPORT: return
	if euclidian_dist >= MAX_EUCLIDIAN_DIST_GUARANTEE_TELEPORT:
		too_far_behind = true
	
	var tiled_dist = next_player_room.route.tiled_dist_to(next_player_room)
	if tiled_dist > MAX_TILED_DIST_BETWEEN_PLAYERS:
		too_far_behind = true
	
	if not too_far_behind: return
	
	body.status.modify_time_penalty(TIME_PENALTY_TOO_FAR_BEHIND)
	body.plan_teleport(get_forward_boost_pos(true))

func get_forward_boost_pos(pick_next_best_player = false):
	var target_room
	if pick_next_best_player:
		var next_player = body.map.route_generator.get_next_best_player(body)
		
		target_room = next_player.room_tracker.get_cur_room()
	else:
		var cur_room_index = body.room_tracker.get_cur_room().route.index
		var target_room_index = (cur_room_index + 1)
		target_room = body.map.route_generator.cur_path[target_room_index]
	
	return body.player_manager.get_spread_out_position(target_room)

func last_cell_has_terrain(t):
	if not last_cell: return false
	return (last_cell.terrain == t)

func last_cell_has_lock():
	if not last_cell: return false
	if not last_cell.room: return false
	
	return last_cell.room.lock.has_lock()
