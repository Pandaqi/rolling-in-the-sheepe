extends Node2D

const MAX_COINS : int = 4
var coins = []

var coins_grabbed : int = 0

var coin_scene = preload("res://scenes/locks/coin.tscn")
onready var my_lock = get_parent()

func _ready():
	_on_Timer_timeout()

func _on_Timer_timeout():
	if coins.size() >= MAX_COINS: return
	place_coin()

func place_coin():
	var coin = coin_scene.instance()
	var rand_pos = my_lock.my_room.get_random_real_position_inside({ 'empty': true })
	coin.set_position(rand_pos)
	add_child(coin)
	
	coins.append(coin)
	
	coin.connect("body_entered", self, "on_coin_grab", [coin])

func on_coin_grab(body, coin):
	if not body.is_in_group("Players"): return
	
	coins.erase(coin)
	coin.queue_free()
	
	body.get_node("Coins").get_paid(1)
	coins_grabbed += 1
	
	my_lock.perform_update()

func delete():
	for c in coins:
		c.queue_free()
