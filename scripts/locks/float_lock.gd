extends "res://scripts/locks/lock_general.gd"

const TARGET_TIME_BOUNDS = { 'min': 7, 'max': 16 }
const MIN_CHANGE_BEFORE_FEEDBACK : float = 0.375

var time_spent_in_air : float = 0.0
var prev_rounded_air_time : float
var target_time : int = 0

onready var label = $Label

func _ready():
	target_time = int(round(rand_range(TARGET_TIME_BOUNDS.min, TARGET_TIME_BOUNDS.max)))
	update_label()

func _physics_process(dt):
	var ents = my_room.entities.get_them()
	for entity in ents:
		if entity.mover.in_air: time_spent_in_air += dt
	
	if ents.size() > 0: update_label()
	check_if_condition_fulfilled()

func check_if_condition_fulfilled():
	if time_spent_in_air < target_time: return
	delete()

func update_label():
	var rounded_air_time = round(time_spent_in_air*10.0)/10.0
	
	if (rounded_air_time - prev_rounded_air_time) > MIN_CHANGE_BEFORE_FEEDBACK:
		on_progress()
	
	label.perform_update(str(rounded_air_time) + "/" + str(target_time) + " s")
	prev_rounded_air_time = rounded_air_time
