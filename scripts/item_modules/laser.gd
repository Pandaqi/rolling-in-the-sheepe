extends Node2D

onready var my_item = get_parent()

onready var timer = $Timer
onready var auto_on_off = $AutoOnOff
onready var laser_tip = $LaserTip

const DISABLE_DURATION : float = 4.5
const AUTO_BOUNDS : Dictionary = { 'min': 4.5, 'max': 7.5 }

func _ready():
	var beam = my_item.area.get_parent()
	beam.set_starting_point(laser_tip.position)
	
	reset_auto_timer()

func _on_Area2D_body_entered(body):
	if not body.is_in_group("Players"): return
	if my_item.area.get_parent().disabled: return
	
	# NOTE: important to disable BEFORE slicing, otherwise we ALSO slice the new bodies!
	disable_my_beam()
	
	body.glue.call_deferred("slice_along_halfway_line")
	body.coins.pay_half()
	
	body.main_particles.create_for_node(body, "explosion", { "place_front": true })
	GAudio.play_dynamic_sound(body, "laser_hit")

func disable_my_beam():
	my_item.get_area_module().disable()

	timer.wait_time = DISABLE_DURATION
	timer.start()

func _on_Timer_timeout():
	my_item.area.get_parent().enable()
	
	reset_auto_timer()

func reset_auto_timer():
	auto_on_off.wait_time = rand_range(AUTO_BOUNDS.min, AUTO_BOUNDS.max)
	auto_on_off.start()

func _on_AutoOnOff_timeout():
	disable_my_beam()
