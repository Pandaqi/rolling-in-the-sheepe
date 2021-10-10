extends Node2D

const MIN_DIST_TO_NEW_ROOM = 10 # in terms of grid tiles, Manhattan distance radius

onready var map = get_node("/root/Main/Map")

var my_room

var old_players_here = {}
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
	
	reset_player_array()

func count_players_here():
	var sum = 0
	for key in players_here:
		if players_here[key].size() > 0:
			sum += 1
	return sum

func reset_player_array():
	old_players_here = players_here
	
	players_here = {}
	for i in GlobalInput.get_player_count():
		players_here[i] = []

func register_player(p):
	players_here[p.get_node("Status").player_num].append(p)
	
	var first_entry = (not timer_is_running)
	if first_entry: start_timer()

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
	# REMARK: by now, all of these have been cleared out, so we need to use the OLD version
	var unteleported_players = []
	var teleported_bodies = []
	for i in range(GlobalInput.get_player_count()):
		unteleported_players.append(i)
	
	# ensure each player has at least ONE piece teleported (even if they didn't make it)
	var teleport_target_pos = map.place_inside_room(map.cur_path[0])
	for key in old_players_here:
		for body in old_players_here[key]:
			body.plan_teleport(teleport_target_pos)
			
			unteleported_players.erase(body.get_node("Status").player_num)
			teleported_bodies.append(body)
	
	var all_bodies = get_tree().get_nodes_in_group("Players")
	for body in all_bodies:
		if unteleported_players.size() <= 0: break
		
		var num = body.get_node("Status").player_num
		var index = unteleported_players.find(num)
		if index < 0: 
			continue
		
		body.plan_teleport(teleport_target_pos)
		unteleported_players.remove(index)
		teleported_bodies.append(body)
	
	# clean up all remaining pieces (that didn't make it at all)
	for body in all_bodies:
		if (body in teleported_bodies): continue
		body.queue_free()
