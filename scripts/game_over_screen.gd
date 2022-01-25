extends Node2D

onready var player_manager = get_node("/root/Main/PlayerManager")
onready var state = get_node("/root/Main/State")
onready var anim_player = $AnimationPlayer

var item_scene = preload("res://scenes/ui/game_over_screen_item.tscn")

onready var who_won_sprite = $WhoWon/Sprite
onready var who_won = $WhoWon
onready var message = $Message

var winner = null

func _ready():
	get_tree().get_root().connect("size_changed", self, "on_resize")
	on_resize()

func on_resize():
	var vp = get_viewport().size
	who_won.set_position(0.5*vp)
	message.set_position(0.5*vp)

func populate(ranks_helper):
	var padding = 15
	var gap = 0
	
	var item_base_size = 128
	var last_item_pos
	
	for i in range(ranks_helper.size()):
		var player_num = ranks_helper[i].num
		if i == 0: winner = player_num
		
		var col = player_manager.player_colors[player_num]
		var shape_frame = player_manager.get_player_shape_frame(player_num)
		var time = ranks_helper[i].time
		
		var item = item_scene.instance()
		item.get_node("Rank").set_text("#" + str(i+1))
		item.get_node("Time").set_text(convert_to_nice_time(time))
		
		item.get_node("BG").modulate = col
		item.get_node("Shape").modulate = col
		item.get_node("Shape").set_frame(shape_frame)
		
		var item_size = item_base_size * item.scale.x
		var pos = Vector2(1,1)*padding + Vector2.DOWN * i * (item_size + gap)
		
		last_item_pos = pos
		item.set_position(pos)
		
		add_child(item)
	
	$Instructions.position = last_item_pos + Vector2.DOWN*50

func convert_to_nice_time(time):
	var minutes = floor(time / 60)
	if minutes < 10:
		minutes = "0" + str(minutes)
	
	var seconds = int(floor(time)) % 60
	if seconds < 10:
		seconds = "0" + str(seconds)
	
	return str(minutes) + ":" + str(seconds)

func show_final_message():
	
	# show correct SHAPE + COLOR of whoever won
	var shape_frame = player_manager.get_player_shape_frame(winner)
	who_won_sprite.set_frame(shape_frame)
	
	var col = player_manager.player_colors[winner]
	who_won_sprite.modulate = col
	
	# play basic revealing animation
	anim_player.play("FinalMessage")

func game_over_anim_finished():
	state.input_enabled = true
