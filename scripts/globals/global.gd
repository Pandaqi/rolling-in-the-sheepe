extends Node

# Options: "tutorial" or "play"
var type : String = "play"
var in_game : bool = true
var scenes = {
	'main': preload("res://Main.tscn"),
	'menu': preload("res://Menu.tscn")
}

func make_all_players_round():
	return (in_game and type == "tutorial") or (not in_game)

func load_game(tp : String):
	type = tp
	in_game = true
	
	# custom config toggleable through main settings
	# should only be a few, so do manually here
	var perf_mode = GConfig.get_config_val("settings", "performance_mode")
	GDict.cfg.performance_mode = perf_mode
	GDict.cfg.paint_on_tilemap = (not perf_mode)
	
	var gen_speed = 2.0
	if perf_mode: gen_speed = 1.0
	GDict.cfg.generation_speed = gen_speed
	GDict.cfg.hide_heavy_particles = perf_mode
	
	GAudio.play_static_sound("ui_button_press")

# warning-ignore:return_value_discarded
	get_tree().change_scene_to(scenes.main)

func restart():
	GAudio.play_static_sound("ui_button_press")
	
	get_tree().reload_current_scene()

func back_to_menu():
	GAudio.play_static_sound("ui_button_press")
	
	in_game = false
# warning-ignore:return_value_discarded
	get_tree().change_scene_to(scenes.menu)

func in_tutorial_mode():
	return (type == "tutorial")

func in_play_mode():
	return (type == "play")
