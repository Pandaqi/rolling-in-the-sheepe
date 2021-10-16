extends Node

const FADE_DURATION : float = 4.0
const MAX_COINS : int = 10

var num_coins : int = 5
var coin_sprite_scene = preload("res://scenes/ui/coin_sprite.tscn")

onready var main_gui = get_node("/root/Main/GUI")

onready var body = get_parent()
onready var my_gui = $GUI
onready var tween = $Tween

func _ready():
	for i in range(MAX_COINS):
		var coin_sprite = coin_sprite_scene.instance()
		coin_sprite.set_visible(false)
		my_gui.add_child(coin_sprite)
	
	remove_child(my_gui)
	main_gui.add_child(my_gui)

func count():
	return num_coins

func as_ratio():
	return num_coins / float(MAX_COINS)

func get_paid(c):
	num_coins = clamp(num_coins + c, 0, MAX_COINS)
	show()

func pay(c):
	num_coins = clamp(num_coins - c, 0, MAX_COINS)
	show()

func _physics_process(_dt):
	position_gui_above_player()

# TO DO: Show the current num_coins in some neat configuration
# TO DO => IDEA => Show the coins _on the player itself_, so we temporarily hide your face? (Not sure if this is great, as shapes can get very small.)
func update_gui():
	var counter = 0
	var coin_sprite_size = 16
	var total_offset = 0.5 * (num_coins-1)*coin_sprite_size * Vector2(1,0)
	
	for child in my_gui.get_children():
		var show = (counter < num_coins)

		var my_offset = counter*coin_sprite_size*Vector2(1,0)
		child.set_visible(show)
		child.set_position(Vector2.ZERO - total_offset + my_offset)
		counter += 1

func show():
	update_gui()
	
	my_gui.set_visible(true)
	my_gui.modulate = Color(1,1,1,1)
	
	tween.interpolate_property(my_gui, "modulate", 
		Color(1,1,1,1), Color(1,1,1,0), FADE_DURATION,
		Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.start()

func _on_Tween_tween_all_completed():
	hide()

func hide():
	my_gui.set_visible(false)

func position_gui_above_player():
	if not my_gui.is_visible(): return
	
	var pos = body.get_global_transform_with_canvas().origin
	var offset = Vector2.UP * 35
	
	my_gui.set_position(pos + offset)
