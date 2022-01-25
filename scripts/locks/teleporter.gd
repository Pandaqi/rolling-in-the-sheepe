extends "res://scripts/locks/lock_general.gd"

const BUFFER_AFTER_TELEPORT : int = 6
const TIME_PENALTY_FOR_MISSING_TELEPORT : float = 10.0

var players_here = {}
var num_players_here : int = 0
var time_left = 15

var timer_is_running : bool = false

onready var label = $Label
onready var solo_mode = get_node("/root/Main/SoloMode")

func _ready():
	for i in GInput.get_player_count():
		players_here[i] = []

func start_timer():
	time_left = 15
	update_label()
	$Timer.start()
	
	timer_is_running = true

func _on_Timer_timeout():
	time_left -= 1
	update_label()
	
	if time_left <= 0:
		perform_teleport()

func update_label():
	label.perform_update(str(time_left))

func _physics_process(_dt):
	var wanted_num_players = GInput.get_player_count()
	num_players_here = count_players_here()
	
	if num_players_here >= wanted_num_players:
		perform_teleport()

func count_players_here():
	var sum = 0
	for key in players_here:
		if players_here[key].size() > 0:
			sum += 1
	return sum

func on_body_enter(p):
	.on_body_enter(p)
	register_player(p)

func on_body_exit(p):
	.on_body_exit(p)
	deregister_player(p)

func register_player(p):
	var player_num = p.status.player_num
	players_here[player_num].append(p)
	
	var first_entry = (not timer_is_running)
	if first_entry: start_timer()

func deregister_player(p):
	var player_num = p.status.player_num
	players_here[player_num].erase(p)

func perform_teleport():
	var cant_teleport_if_no_players = (num_players_here <= 0) and GDict.cfg.dont_teleport_if_no_players
	if cant_teleport_if_no_players:
		time_left = 15
		update_label()
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
	
	var new_pos_margin = 5
	map.room_picker.create_new_room( map.get_random_grid_pos(new_pos_margin) )
	
	# teleport all players there
	var unteleported_players = []
	var teleported_bodies = []
	for i in range(GInput.get_player_count()):
		unteleported_players.append(i)
	
	var teleport_target_pos = map.route_generator.cur_path[0].rect.get_real_center()
	var teleport_target_room = map.route_generator.cur_path[0]
	
	for key in players_here:
		for body in players_here[key]:
			var final_pos = map.player_manager.get_spread_out_position(teleport_target_room)
			body.plan_teleport(final_pos)
			
			unteleported_players.erase(body.status.player_num)
			teleported_bodies.append(body)
	
	# ensure each player has at least ONE piece teleported (even if they didn't make it)
	var all_bodies = get_tree().get_nodes_in_group("Players")
	for body in all_bodies:
		if unteleported_players.size() <= 0: break
		
		var num = body.status.player_num
		var index = unteleported_players.find(num)
		if index < 0: continue
		
		var final_pos = map.player_manager.get_spread_out_position(teleport_target_room)
		
		body.status.modify_time_penalty(TIME_PENALTY_FOR_MISSING_TELEPORT)
		
		body.plan_teleport(final_pos)
		unteleported_players.remove(index)
		teleported_bodies.append(body)
	
	# clean up all remaining pieces (that didn't make it at all)
	for body in all_bodies:
		if (body in teleported_bodies): continue
		body.status.delete(false) # @param "part_of_slice"
	
	# do ONE sound effect for all of them
	GAudio.play_dynamic_sound({ 'global_position': teleport_target_pos }, "teleport")
	
	# introduce another buffer
	for _i in range(BUFFER_AFTER_TELEPORT):
		map.room_picker.create_new_room()
	
	map.route_generator.is_teleporting = false
