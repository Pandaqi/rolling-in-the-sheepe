extends Node

var type : String = "play"
var in_game : bool = false
var scenes = {
	'main': preload("res://Main.tscn"),
	'menu': preload("res://Menu.tscn")
}

func make_all_players_round():
	return (in_game and type == "tutorial") or (not in_game)

func load_game(tp : String):
	type = tp
	in_game = true
# warning-ignore:return_value_discarded
	get_tree().change_scene_to(scenes.main)

func back_to_menu():
	in_game = false
# warning-ignore:return_value_discarded
	get_tree().change_scene_to(scenes.menu)
