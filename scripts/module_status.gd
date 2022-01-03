extends Node

onready var body = get_parent()
onready var face = get_node("../Face")
onready var glue = get_node("../Glue")
onready var rounder = get_node("../Rounder")

onready var player_progression = get_node("/root/Main/Map/PlayerProgression")
onready var player_manager = get_node("/root/Main/PlayerManager")

var player_num : int = -1
var shape_name : String = ""
var is_menu : bool = false

var time_penalty : float = 0.0
var has_finished : bool = false

var is_wolf : bool = false

onready var invincibility_timer = $InvincibilityTimer
var is_invincible : bool = false

# Deletes the whole body, but not before (re)setting all sorts of other properties
# that _should_ be properly reset
func delete():
	player_progression.on_body_removed(body)
	player_manager.deregister_body(body)
	
	body.get_node("Glue").disable_glue()
	body.get_node("RoomTracker").get_cur_room().entities.remove_player(body)
	body.get_node("Coins").delete()
	
	body.queue_free()

func set_shape_name(nm : String):
	shape_name = nm

func set_player_num(num : int):
	player_num = num
	
	if has_node("../Input"):
		get_node("../Input").set_player_num(num)
	
	if has_node("../Glue"):
		get_node("../Glue").set_player_num(num)
	
	if has_node("../Shaper"):
		get_node("../Shaper").set_color(player_manager.player_colors[num])

# TO DO: Need to completely rewrite tutorial module anyway
#	if has_node("../Tutorial"):
#		var global_tutorial = get_node("/root/Main/Tutorial")
#		var module_tutorial = get_node("../Tutorial")
#		if global_tutorial.is_active():
#			module_tutorial.activate()
#		else:
#			module_tutorial.queue_free()
	
	player_manager.register_body(body)
	
	make_sheep()
	make_invincible()

func modify_time_penalty(val):
	time_penalty += val
	
	if val < 0:
		body.feedback.create_for_node(body, "Time bonus!")
	elif val > 0:
		body.feedback.create_for_node(body, "Time penalty!")

func make_ghost():
	body.feedback.create_for_node(body, "Ghost!")
	
	body.collision_layer = 0
	body.collision_mask = 1
	
	body.modulate.a = 0.5

# Layers 1 (2^0; all) and 3 (2^2; players)
func undo_ghost():
	body.feedback.create_for_node(body, "Unghosted!")
	
	body.collision_layer = 1 + 4
	body.collision_mask = 1 + 4
	
	body.modulate.a = 1.0

func make_wolf():
	if not is_wolf: body.feedback.create_for_node(body, "Wolf!")
	
	is_wolf = true
	face.make_wolf()
	
	if not is_menu:
		glue.make_wolf()
		rounder.start_grow_mode("shrink")

func make_sheep():
	if is_wolf: body.feedback.create_for_node(body, "Sheep!")
	
	is_wolf = false
	face.make_sheep()
	
	if not is_menu:
		glue.make_sheep()
		rounder.end_grow_mode()

func make_invincible(start_timer = true):
	is_invincible = true
	
	# if we start a timer, it means its an automatic invincibility (which I apply behind the scenes), so don't show feedback
	if start_timer:
		invincibility_timer.start()
	else:
		body.feedback.create_for_node(body, "Invincible!")

func make_vincible(from_timer = false):
	if not from_timer: body.feedback.create_for_node(body, "Not invincible!")
	
	is_invincible = false

func _on_InvincibilityTimer_timeout():
	make_vincible(true)
