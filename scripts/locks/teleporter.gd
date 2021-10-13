extends Node2D

const TIME_PENALTY_FOR_MISSING_TELEPORT : float = 10.0
const MIN_DIST_TO_NEW_ROOM = 10 # in terms of grid tiles, Manhattan distance radius

onready var player_manager = get_node("/root/Main/PlayerManager")
onready var map = get_node("/root/Main/Map")

var my_room

var players_here = {}
var num_players_here : int = 0
var time_left = 15

var timer_is_running : bool = false

func _ready():
	for i in GlobalInput.get_player_count():
		players_here[i] = []
	
	$Label.set_position(my_room.get_free_real_pos_inside())

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
	$Label/Label.set_text(str(time_left))

func _physics_process(dt):
	var wanted_num_players = GlobalInput.get_player_count()
	num_players_here = count_players_here()
	
	if num_players_here >= wanted_num_players:
		perform_teleport()

func count_players_here():
	var sum = 0
	for key in players_here:
		if players_here[key].size() > 0:
			sum += 1
	return sum

func register_player(p):
	var player_num = p.get_node("Status").player_num
	players_here[player_num].append(p)
	
	var first_entry = (not timer_is_running)
	if first_entry: start_timer()

func deregister_player(p):
	var player_num = p.get_node("Status").player_num
	players_here[player_num].erase(p)

func delete():
	self.queue_free()

func perform_teleport():
	var cant_teleport_if_no_players = (num_players_here <= 0)
	if cant_teleport_if_no_players:
		time_left = 15
		update_label()
		return
	
	$Timer.queue_free()
	$Label/Label.set_text("!")
	
	print("Everyone here; teleport!")
	
	# pick a new location (sufficiently far from teleporter room)
	var last_room = map.get_furthest_room()
	
	var new_pos
	var bad_choice = true
	
	while bad_choice:
		new_pos = map.get_random_grid_pos() 
		bad_choice = ((new_pos - last_room.pos).length() < MIN_DIST_TO_NEW_ROOM)
	
	# destroy all old rooms
	map.delete_all_rooms()
	
	# create the new one
	map.pause_room_generation = false
	map.create_new_room(new_pos)
	
	# teleport all players there
	var unteleported_players = []
	var teleported_bodies = []
	for i in range(GlobalInput.get_player_count()):
		unteleported_players.append(i)
	
	var teleport_target_pos = map.place_inside_room(map.cur_path[0])
	for key in players_here:
		for body in players_here[key]:
			var final_pos = player_manager.get_spread_out_position(teleport_target_pos)
			body.plan_teleport(final_pos)
			
			unteleported_players.erase(body.get_node("Status").player_num)
			teleported_bodies.append(body)
	
	# ensure each player has at least ONE piece teleported (even if they didn't make it)
	var all_bodies = get_tree().get_nodes_in_group("Players")
	for body in all_bodies:
		if unteleported_players.size() <= 0: break
		
		var num = body.get_node("Status").player_num
		var index = unteleported_players.find(num)
		if index < 0: 
			continue
		
		var final_pos = player_manager.get_spread_out_position(teleport_target_pos)
		
		body.get_node("Status").modify_time_penalty(TIME_PENALTY_FOR_MISSING_TELEPORT)
		
		body.plan_teleport(final_pos)
		unteleported_players.remove(index)
		teleported_bodies.append(body)
	
	# clean up all remaining pieces (that didn't make it at all)
	for body in all_bodies:
		if (body in teleported_bodies): continue
		body.queue_free()
