extends Node2D

onready var tut_helper = $TutorialArea/Helper
onready var play_helper = $PlayArea/Helper

onready var tut_door = $TutorialDoor
onready var play_door = $PlayDoor

onready var tween = $Tween
onready var players = $PlayerManager
onready var settings = $TechnicalSettings

var helpers_shown : bool = false

func _ready():
	tut_helper.modulate.a = 0.0
	play_helper.modulate.a = 0.0
	
	players.activate()
	settings.activate()

func on_player_logged_in():
	$TutorialArea.stop_preparing()
	$PlayArea.stop_preparing()
	
	if helpers_shown: return
	
	var dur = 1.0
	
	tween.interpolate_property(tut_helper, "modulate",
		tut_helper.modulate, Color(1,1,1,1), dur,
		Tween.TRANS_BOUNCE, Tween.EASE_OUT)
	
	tween.interpolate_property(play_helper, "modulate",
		play_helper.modulate, Color(1,1,1,1), dur,
		Tween.TRANS_BOUNCE, Tween.EASE_OUT)

	helpers_shown = true
	
	var door_dur = 8.0
	var door_offset =  Vector2.UP*96*2
	
	tween.interpolate_property(tut_door, "position",
		tut_door.position, tut_door.position + door_offset, door_dur,
		Tween.TRANS_CUBIC, Tween.EASE_IN)
	
	tween.interpolate_property(play_door, "position",
		play_door.position, play_door.position + door_offset, door_dur,
		Tween.TRANS_CUBIC, Tween.EASE_IN)
		
	tween.start()
