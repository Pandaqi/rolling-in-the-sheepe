extends Node2D

onready var map = $Map
onready var player_manager = $PlayerManager
onready var state = $State
onready var gui = $GUI
onready var solo_mode = $SoloMode
onready var pause_menu = $PauseMenu
onready var game_over_loss_visuals = $GameOverLossVisuals

func _init():
	if G.in_game and GInput.get_player_count() <= 0:
		GInput.create_debugging_players()

func _ready():
	map.generate()
	player_manager.activate()
	solo_mode.activate()
	state.activate()
