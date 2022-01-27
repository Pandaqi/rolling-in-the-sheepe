extends "res://scripts/locks/lock_general.gd"

const BUFFER_AFTER_TELEPORT : int = 6
const TIME_PENALTY_FOR_MISSING_TELEPORT : float = 10.0

var time_left = 15

var timer_is_running : bool = false
var activated : bool = false

onready var label = $Label
onready var solo_mode = get_node("/root/Main/SoloMode")

func start_timer():
	var teleporter_time = 10
	if solo_mode.is_active(): teleporter_time = 5
	
	time_left = teleporter_time
	update_label()
	$Timer.start()
	
	timer_is_running = true

func _on_Timer_timeout():
	if activated: return
	
	time_left -= 1
	update_label()
	
	if time_left <= 0:
		activated = true
		call_deferred("perform_teleport")

func update_label():
	label.perform_update(str(time_left))

# only needed for starting the initial timer
func on_body_enter(p):
	.on_body_enter(p)
	
	var first_entry = (not timer_is_running)
	if first_entry: start_timer()

func perform_teleport():
	# NOTE: not really well tested/implemented, this one
	var cant_teleport_if_no_players = (not my_room.entities.has_some()) and GDict.cfg.dont_teleport_if_no_players
	if cant_teleport_if_no_players:
		start_timer()
		return
	
	solo_mode.disable_temporarily()
	map.route_generator.disable_temporarily()
	
	$Timer.queue_free()
	label.perform_update("!")

	# destroy all old rooms
	map.route_generator.is_teleporting = true
	map.route_generator.delete_all_rooms()
	
	# create the new one
	map.route_generator.pause_room_generation = false
	
	var new_pos_margin = 9
	map.room_picker.create_new_room( map.get_random_grid_pos(new_pos_margin) )
	
	var teleport_target_pos = map.route_generator.cur_path[0].rect.get_real_center()
	var teleport_target_room = map.route_generator.cur_path[0]
	
	var all_bodies = get_tree().get_nodes_in_group("Players")
	for body in all_bodies:
		if not body or not is_instance_valid(body): continue
		var final_pos = map.player_manager.get_spread_out_position(teleport_target_room)
		body.plan_teleport(final_pos)
	
	# do ONE sound effect for all of them
	GAudio.play_dynamic_sound({ 'global_position': teleport_target_pos }, "teleport")
	
	# introduce another buffer
	for _i in range(BUFFER_AFTER_TELEPORT):
		map.room_picker.create_new_room()
	
	map.route_generator.is_teleporting = false
