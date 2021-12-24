extends Node

var config = null

var settings_file_path = "user://settings.cfg"
var settings = [
	# AUDIO
	{ 
		"sec": "audio", 
		"label": "Main Volume",
		"name": "MainVolume", 
		"comp": "HSlider", 
		"def": 0.75,
		"range": { "min": 0.0001, "max": 1.0 }
	},
	
	{ 
		"sec": "audio", 
		"label": "FX Volume",
		"name": "FXVolume", 
		"comp": "HSlider", 
		"def": 0.85,
		"range": { "min": 0.0001, "max": 1.0 }
	},
	
	{ 
		"sec": "audio", 
		"label": "UI Volume",
		"name": "GUIVolume", 
		"comp": "HSlider", 
		"def": 0.6,
		"range": { "min": 0.0001, "max": 1.0 }
	},
	
	# VISUALS
	{ 
		"sec": "visuals", 
		"label": "Fullscreen",
		"name": "Fullscreen", 
		"comp": "Checkbox", 
		"def": true 
	},
]

func _ready():
	randomize()
	load_config()

func check_config():
	if not config: load_config()
	
	for i in range(settings.size()):
		var s = settings[i]
		
		# setting not there yet? add the default value ("def")
		if not config.has_section_key(s.sec, s.name):
			config.set_value(s.sec, s.name, s.def)
		
		# immediately update in-game as well
		update_setting_in_game(s.name, get_config_val(s.sec, s.name))
		
	config.save(settings_file_path)

func load_config():
	# load config file
	config = ConfigFile.new()
	var err = config.load(settings_file_path)
	
	# doesn't exist yet? save it, so it does exist next time
	if err != OK: config.save(settings_file_path)
	
	# now check whether values already exist, and if not, setting them to default
	check_config()

func update_setting_in_game(node_name, val):
	
	# audio is instantly updated, as it's present everywhere in the game
	if node_name == "MainVolume":
		var conv_val = log(val) * 20
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("BG"), conv_val)
	elif node_name == "FXVolume":
		var conv_val = log(val) * 20
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("FX"), conv_val)
	elif node_name == "GUIVolume":
		var conv_val = log(val) * 20
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("GUI"), conv_val)
	
	# same for fullscreen
	elif node_name == "Fullscreen":
		OS.window_fullscreen = val

func update_config_val(data, new_val):
	if not config: load_config()
	
	config.set_value(data.sec, data.name, new_val)
	config.save(settings_file_path)
	
	update_setting_in_game(data.name, new_val)

func get_config_val(sec, nm):
	# get known value from config file
	var known_val = config.get_value(sec, nm, null)
	if known_val != null: return known_val
	
	# doesn't exist? check if settings has a default value, return that
	if settings.has(nm): return settings[nm].def
	
	# still nothing? return false
	return 0

func get_config():
	if not config: load_config()
	return config

func get_settings():
	return settings
