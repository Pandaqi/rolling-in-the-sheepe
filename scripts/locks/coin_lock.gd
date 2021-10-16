extends Node2D

const MAX_COINS : int = 4
var coins = []

var coins_to_grab : int = 5
var coins_grabbed : int = 0

var coin_scene = preload("res://scenes/locks/coin.tscn")
var my_room

onready var label : Node2D = $Label

func _ready():
	coins_to_grab = 5 + randi() % 3
	
	position_label()
	update_label()
	
	_on_Timer_timeout()

func _on_Timer_timeout():
	if coins.size() >= MAX_COINS: return
	place_coin()

func place_coin():
	var coin = coin_scene.instance()
	coin.set_position(my_room.get_random_real_position_inside({ 'empty': true }))
	add_child(coin)
	
	coins.append(coin)
	
	coin.connect("body_entered", self, "on_coin_grab", [coin])

func on_coin_grab(body, coin):
	if not body.is_in_group("Players"): return
	
	coins.erase(coin)
	coin.queue_free()
	
	body.get_node("Coins").get_paid(1)
	
	coins_grabbed += 1
	update_label()
	
	check_if_condition_fulfilled()

func check_if_condition_fulfilled():
	if coins_grabbed < coins_to_grab: return
	
	delete()

func delete():
	for c in coins:
		c.queue_free()
	self.queue_free()
	
	my_room.remove_lock()

func position_label():
	label.set_position(my_room.get_free_real_pos_inside())

func update_label():
	label.get_node("Label").set_text(str(coins_grabbed) + "/" + str(coins_to_grab))
