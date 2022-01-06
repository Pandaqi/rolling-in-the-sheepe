extends Node2D

onready var my_lock = get_parent()
onready var tween = $Tween
onready var label = $Label

func _ready():
	label.set_text("?")
	position_label()

func position_label():
	set_position(my_lock.my_room.rect.get_free_real_pos_inside())

func perform_update(val):
	label.set_text(val)
	flash_label()

func flash_label():
	var start = Vector2.ONE
	var end = Vector2.ONE*1.5
	var dur = 0.4
	
	set_scale(end)
	tween.interpolate_property(self, "scale",
		end, start, dur, 
		Tween.TRANS_BOUNCE, Tween.EASE_OUT)
	
	tween.interpolate_property(self, "modulate",
		Color(1,0.5,0.5), Color(1,1,1), dur,
		Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.start()
