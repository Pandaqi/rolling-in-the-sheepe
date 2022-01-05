extends "res://scripts/locks/lock_general.gd"

var types = ["regular", "timed", "order", "simultaneous"]
var sub_type = ""
var buttons = []

var buttons_pushed : int = 0
var buttons_to_push : int = 0

onready var label = $Label

func _ready():
	spawn_buttons()
	update_label()

func update_label():
	label.perform_update(str(buttons_pushed) + "/" + str(buttons_to_push))

func set_sub_type(tp):
	sub_type = tp

func record_button_push(item):
	GAudio.play_dynamic_sound(item, "button")
	
	if sub_type == "order":
		if item.general_parameter > buttons_pushed:
			return false
		
		map.special_elements.erase(item)
	
	elif sub_type == "simultaneous":
		buttons_pushed = buttons_to_push
	
	elif sub_type == "timed":
		map.special_elements.erase(item)
	
	my_room.main_particles.create_at_pos(item.global_position, "general_powerup", { 'subtype': 'checkmark' })
	
	on_progress()
	buttons_pushed += 1
	update_label()
	check_if_condition_fulfilled()
	return true

func check_if_condition_fulfilled():
	if buttons_pushed < buttons_to_push: return
	
	delete()

func spawn_buttons():
	var num_buttons = 2 + randi() % 4
	if sub_type == "simultaneous":
		num_buttons = 2
		if GInput.get_player_count() >= 4: 
			num_buttons = 2 + randi() % 2
	
	buttons = []
	var final_buttons_placed = 0
	for i in range(num_buttons):
		var new_button = my_room.items.add_special_item({ 'type': "button_" + sub_type , 'use_shrunk': true, 'ignore_size': true })
		if not new_button: break
		
		if sub_type == "order":
			new_button.set_general_parameter(i)
		
		buttons.append(new_button)
		final_buttons_placed += 1

	buttons_to_push = final_buttons_placed
	update_label()

func is_invalid() -> bool:
	return buttons.size() <= 0

func erase_all_buttons():
	for btn in buttons:
		map.special_elements.erase(btn)

func _physics_process(_dt):
	if sub_type != "simultaneous": return
	
	var num_pressed = 0
	for btn in buttons:
		if btn.has_overlapping_bodies():
			num_pressed += 1
	
	if num_pressed >= buttons_to_push:
		erase_all_buttons()
		record_button_push(null)
