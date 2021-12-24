extends Node


var bg_audio = null
var bg_audio_player

var active_players = []

var bg_audio_preload = {}
var audio_preload = {
	
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
		audio_player = AudioStreamPlayer3D.new()
		audio_player.unit_db = volume_alteration
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
		max_dist = 2000
		pos = creator.get_global_position()
		audio_player.set_position(pos)
	else:
		max_dist = 100
		pos = creator.get_translation()
		audio_player.set_translation(pos)
		
		audio_player.unit_size = 100

	audio_player.max_distance = max_dist
	audio_player.pitch_scale = 1.0 + 0.02*(randf()-0.5)
	
	add_child(audio_player)
	
	audio_player.stream = pick_audio(key)
	audio_player.play()
	
	return audio_player
