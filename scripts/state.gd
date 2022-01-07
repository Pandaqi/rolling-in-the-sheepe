extends Node2D

var game_over_screen = preload("res://scenes/ui/game_over_screen.tscn")

var player_raw_times = {}
var player_times = {}
var player_ranks_helper = []
var player_ranks = []
var num_players_finished : int = 0

var game_start : float = 0.0
var game_over_mode : bool = false

onready var main_node = get_parent()

func activate():
	game_start = OS.get_ticks_msec()
	GAudio.play_static_sound("game_start")

func _input(ev):
	if not game_over_mode: return
	
	if ev.is_action_released("ui_restart"):
# warning-ignore:return_value_discarded
		G.restart()
	elif ev.is_action_released("ui_exit"):
		G.back_to_menu()

func show_finish_game_over_screen():
	var screen = game_over_screen.instance()
	main_node.gui.add_child(screen)
	
	# TO DO => find a good position out of the way of players
	# (give camera unique focus type where "players = one side, gui = other")
	screen.set_position(Vector2.ZERO)
	screen.populate(player_ranks, player_times)
	
	# NOTE: _must_ come after populate, as that also remembers who actually won and stuff
	screen.show_final_message()

func show_loss_game_over_screen():
	main_node.game_over_loss_visuals.activate()

func check_if_game_over():
	if num_players_finished < GInput.get_player_count(): return
	game_over(true)

func game_over(we_won : bool = false):
	if game_over_mode: return
	
	print("GAME OVER")
	
	game_over_mode = true
	main_node.map.route_generator.get_furthest_room().outline.seal()
	main_node.pause_menu.disable()
	main_node.solo_mode.deactivate()
	
	# TO DO: Create a special "game_end" melody?
	# In fact, differentiate between losing and winning?
	GAudio.play_static_sound("game_start")
	
	if we_won:
		show_finish_game_over_screen()
	else:
		show_loss_game_over_screen()

func player_finished(b):
	var player_num = b.status.player_num
	var player_already_finished = player_times.has(player_num)

	var raw_time = (OS.get_ticks_msec() - game_start) / 1000.0
	if not player_already_finished:
		player_raw_times[player_num] = raw_time
	else:
		raw_time = player_raw_times[player_num]
	
	var time_modifiers = 0
	
	# All player bodies contribute
	for body in main_node.player_manager.bodies_per_player[player_num]:
		
		# Can come from anything: being too far behind, standing still too long, missing a teleport, ...
		time_modifiers += body.status.time_penalty
		
		if body.status.has_finished: continue
		time_modifiers += GDict.cfg.time_penalty_unfinished_bodies
	
	# Calculate final time (from raw time of first body + modifiers)
	var final_time = raw_time + time_modifiers
	player_times[player_num] = final_time
	
	# erase previous entry and overwrite with new time
	for entry in player_ranks_helper:
		if entry.num == player_num: player_ranks_helper.erase(entry)
	player_ranks_helper.append({ 'num': player_num, 'time': final_time })
	
	if not player_already_finished:
		num_players_finished += 1
	
	update_ranks()
	check_if_game_over()
	
	return { 'already_finished': false, 'rank': get_player_rank(player_num) }

func rank_sort_function(a,b):
	return a.time < b.time

func get_player_rank(num):
	return player_ranks[num]

func update_ranks():
	player_ranks_helper.sort_custom(self, "rank_sort_function")
	
	player_ranks = []
	player_ranks.resize(GInput.get_player_count())
	
	for i in range(player_ranks_helper.size()):
		player_ranks[player_ranks_helper[i].num] = i
	
	var players = get_tree().get_nodes_in_group("Players")
	for p in players:
		if not p.map_reader.has_gui(): continue
		
		var player_num = p.status.player_num
		p.map_reader.set_gui_rank(get_player_rank(player_num))
