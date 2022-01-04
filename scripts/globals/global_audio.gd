extends Node

const MAX_DIST_2D : float = 2000.0
const MAX_DIST_3D : float = 100.0

var is_3D : bool = false

var bg_audio = null
var bg_audio_player

var active_players = []

var bg_audio_preload = {}
var audio_preload = {
	# movement
	"hit": [
		preload("res://assets/audio/hit1.ogg"),
		preload("res://assets/audio/hit2.ogg"),
		preload("res://assets/audio/hit3.ogg"),
		preload("res://assets/audio/hit4.ogg"),
		preload("res://assets/audio/hit5.ogg")
	],
	"jump": preload("res://assets/audio/jump.ogg"),
	"float": [
		preload("res://assets/audio/whoosh_1.ogg"),
		preload("res://assets/audio/whoosh_2.ogg"),
		preload("res://assets/audio/whoosh_3.ogg")
	],
	
	# game loop
	"teleport": preload("res://assets/audio/teleport.ogg"),
	"finish": preload("res://assets/audio/finish.ogg"),
	"lock_unlocked": preload("res://assets/audio/lock_unlocked.ogg"),
	"player_logged_in": [
		preload("res://assets/audio/login1.ogg"),
		preload("res://assets/audio/login2.ogg"),
		preload("res://assets/audio/login3.ogg"),
		preload("res://assets/audio/login4.ogg"),
		preload("res://assets/audio/login5.ogg"),
		preload("res://assets/audio/login6.ogg"),
		preload("res://assets/audio/login7.ogg")
	],
	"game_start": preload("res://assets/audio/game_start.ogg"),
	"slice": [
		preload("res://assets/audio/slash1.ogg"),
		preload("res://assets/audio/slash2.ogg"),
		preload("res://assets/audio/slash3.ogg"),
		preload("res://assets/audio/slash4.ogg"),
		preload("res://assets/audio/slash5.ogg")
	],
	
	# status
	"plop_single": preload("res://assets/audio/plop_single.ogg"),
	"plop_multiple": preload("res://assets/audio/plop_multiple.ogg"),
	"ghost": preload("res://assets/audio/ghost.ogg"),
	"wolf": preload("res://assets/audio/wolf.ogg"),
	"sheep": preload("res://assets/audio/sheep.ogg"),
	"shield_start": preload("res://assets/audio/shield_start.ogg"),
	"shield_end": preload("res://assets/audio/shield_end.ogg"),
	"non_slice_destroy": preload("res://assets/audio/non_slice_destroy.ogg"),
	
	# UI
	"ui_button_press": preload("res://assets/audio/ui_button_press.ogg"),
	"ui_selection_change": preload("res://assets/audio/ui_selection_change.ogg"),
	
	# locks
	"lock_progress": preload("res://assets/audio/lock_progress.ogg"),
	"button": [
		preload("res://assets/audio/button_1.ogg"),
		preload("res://assets/audio/button_2.ogg")
	],
	"coin": preload("res://assets/audio/coin.ogg"),
	"paint": [
		preload("res://assets/audio/paint_1.ogg"),
		preload("res://assets/audio/paint_2.ogg"),
		preload("res://assets/audio/paint_3.ogg"),
		preload("res://assets/audio/paint_4.ogg"),
		preload("res://assets/audio/paint_5.ogg")
	],
	"gate_close": preload("res://assets/audio/gate_close.ogg"),
	"gate_open": preload("res://assets/audio/gate_open.ogg"),
	
	# terrains
	"speedup": preload("res://assets/audio/battery_up.ogg"),
	"slowdown": preload("res://assets/audio/battery_down.ogg"),
	"magnet": preload("res://assets/audio/magnet.ogg"),
	
	# special tiles
	"ice": preload("res://assets/audio/ice.ogg"),
	"spiderman": preload("res://assets/audio/spiderman.ogg"),
	"glue": preload("res://assets/audio/glue.ogg"),
	"freeze": preload("res://assets/audio/freeze.ogg"),
	"time": preload("res://assets/audio/time.ogg"),
	"laser_hit": preload("res://assets/audio/laser_hit.ogg"),
	"bullet_shot": [
		preload("res://assets/audio/bullet_shot_1.ogg"),
		preload("res://assets/audio/bullet_shot_2.ogg"),
	],
	"bullet_hit": preload("res://assets/audio/bullet_hit.ogg"),
	"explode": preload("res://assets/audio/explode.ogg")
}

func _ready():
	create_background_stream()

func create_background_stream():
	bg_audio_player = AudioStreamPlayer.new()
	add_child(bg_audio_player)
	
	bg_audio_player.bus = "BG"
	
	var stream = bg_audio
	if not stream and bg_audio_preload.has("default"): stream = bg_audio_preload["default"]
	
	if not stream: return
	
	bg_audio_player.stream = stream
	bg_audio_player.play()
	
	bg_audio_player.pause_mode = Node.PAUSE_MODE_PROCESS

func change_bg_stream(key : String):
	bg_audio_player.stop()
	bg_audio_player.stream = bg_audio_preload[key]
	bg_audio_player.play()

func pick_audio(key):
	var wanted_audio = audio_preload[key]
	if wanted_audio is Array: wanted_audio = wanted_audio[randi() % wanted_audio.size()]
	return wanted_audio

func create_audio_player(volume_alteration, bus : String = "FX", spatial : bool = false, destroy_when_done : bool = true):
	var audio_player
	
	if spatial:
		if is_3D:
			audio_player = AudioStreamPlayer3D.new()
			audio_player.unit_db = volume_alteration
		else:
			audio_player = AudioStreamPlayer2D.new()
			audio_player.volume_db = volume_alteration
	else:
		audio_player = AudioStreamPlayer.new()
		audio_player.volume_db = volume_alteration
	
	audio_player.bus = bus
	
	active_players.append(audio_player)
	
	if destroy_when_done:
		audio_player.connect("finished", self, "audio_player_done", [audio_player])
	#audio_player.pause_mode = Node.PAUSE_MODE_PROCESS
	
	return audio_player

func audio_player_done(which_one):
	active_players.erase(which_one)
	which_one.queue_free()

func play_static_sound(key, volume_alteration = 0, bus : String = "GUI"):
	if not audio_preload.has(key): return
	
	var audio_player = create_audio_player(volume_alteration, bus)

	add_child(audio_player)
	
	audio_player.stream = pick_audio(key)
	audio_player.pitch_scale = 1.0 + 0.02*(randf()-0.5)
	audio_player.play()
	
	return audio_player

func play_dynamic_sound(creator, key, volume_alteration = 0, bus : String = "FX", destroy_when_done : bool = true):
	if not audio_preload.has(key): return
	var audio_player = create_audio_player(volume_alteration, bus, true, destroy_when_done)
	
	var pos = null
	var max_dist = -1
	if audio_player is AudioStreamPlayer2D:
		max_dist = MAX_DIST_2D
		pos = creator.global_position
		audio_player.set_position(pos)
	else:
		max_dist = MAX_DIST_3D
		audio_player.unit_size = max_dist
		pos = creator.transform.origin
		audio_player.set_translation(pos)

	audio_player.max_distance = max_dist
	audio_player.pitch_scale = 1.0 + 0.02*(randf()-0.5)
	
	add_child(audio_player)
	
	audio_player.stream = pick_audio(key)
	audio_player.play()
	
	return audio_player
