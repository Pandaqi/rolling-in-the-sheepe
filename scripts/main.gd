extends Node2D

onready var map = $Map
onready var player_manager = $PlayerManager

func _ready():
	map.generate()
	player_manager.activate()
