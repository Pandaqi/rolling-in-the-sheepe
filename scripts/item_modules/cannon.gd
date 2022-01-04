extends Node2D

var bullet_scene = preload("res://scenes/projectiles/bullet.tscn")

const BULLET_INTERVAL : float = 2.25
const BULLET_FORCE : float = 150.0

onready var timer = $Timer
onready var barrel_tip = $BarrelTip
onready var map = get_node("/root/Main/Map")

func _ready():
	timer.wait_time = BULLET_INTERVAL
	timer.start()
	
	shoot_bullet()

func _on_Timer_timeout():
	shoot_bullet()

func shoot_bullet():
	var normal = get_parent().transform.x
	var b = bullet_scene.instance()
	map.add_child(b)
	
	b.set_starting_velocity(normal * BULLET_FORCE)
	b.set_position(barrel_tip.global_position)
	
	GAudio.play_dynamic_sound(barrel_tip, "bullet_shot")
