extends Node2D

onready var map = $Map
onready var player_manager = $PlayerManager
onready var gui = $GUI

var game_over_screen = preload("res://scenes/ui/game_over_screen.tscn")

var player_times = {}
var player_ranks_helper = []
var player_ranks = []
var num_players_finished : int = 0

var game_start : float = 0.0

var game_over_mode : bool = false

func _ready():
	map.generate()
	player_manager.activate()
	
	game_start = OS.get_ticks_msec()

func _input(ev):
	if not game_over_mode: return
	
	if ev.is_action_released("ui_restart"):
		get_tree().reload_current_scene()
	elif ev.is_action_released("ui_exit"):
		print("Should exit to menu")

func show_game_over_screen():
	var screen = game_over_screen.instance()
	gui.add_child(screen)
	
	# TO DO => find a good position out of the way of players
	# (give camera unique focus type where "players = one side, gui = other")
	screen.set_position(Vector2.ZERO)
	
	screen.populate(player_ranks, player_times)

func check_if_game_over():
	if num_players_finished < GlobalInput.get_player_count(): return
	
	print("GAME OVER")
	game_over_mode = true
	show_game_over_screen()

func player_finished(b):
	var player_num = b.get_node("Status").player_num
	var player_already_finished = player_times.has(player_num)
	
	if player_already_finished: 
		return { 'already_finished': true, 'rank': -1 }
	
	var raw_time = (OS.get_ticks_msec() - game_start) / 1000.0
	
	# TO DO (powerups that give time penalties or something)
	var time_modifiers = b.get_node("Status").time_penalty
	
	var final_time = raw_time + time_modifiers
	player_times[player_num] = final_time
	player_ranks_helper.append({ 'num': player_num, 'time': final_time })
	
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
	player_ranks.resize(GlobalInput.get_player_count())
	
	for i in range(player_ranks_helper.size()):
		player_ranks[player_ranks_helper[i].num] = i
	
	var players = get_tree().get_nodes_in_group("Players")
	for p in players:
		if not p.get_node("MapReader").has_gui(): continue
		
		var player_num = p.get_node("Status").player_num
		p.get_node("MapReader").set_gui_rank(get_player_rank(player_num))
