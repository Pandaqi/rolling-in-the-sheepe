extends Node2D

const ITEM_EFFECT_DURATION : float = 5.0
const TIMEOUT_DURATION : float = 1.0

onready var body = get_parent()
onready var map = get_node("/root/Main/Map")

onready var ongoing_timer = $OngoingTimer
onready var timeout_timer = $TimeoutTimer

var immediate_items = []
var ongoing_items = []

var on_timeout : bool = false

func _physics_process(_dt):
	reset_immediate_items()
	
	var cur_items = ongoing_items.size()
	for obj in body.contact_data:
		if not (obj.body is TileMap): continue

		register_contact(obj)
	
	var received_ongoing_effect = ongoing_items.size() > cur_items
	if received_ongoing_effect:
		start_ongoing_timer()
	
	do_something_with_items()

func register_contact(obj):
	var grid_pos = map.get_grid_pos(obj.pos)
	if map.out_of_bounds(grid_pos): return
	
	var cell = map.get_cell(grid_pos)
	if not cell.special: return
	
	var type = cell.special.type
	
	if map.special_elements.type_is_immediate(type):
		immediate_items.append(type)
	else:
		ongoing_items.append(type)
		do_ongoing(type)

#
# Immediate items
# (these are triggered every frame you touch them, immediately, and then reset at the end of the frame)
#
func do_something_with_items():
	if on_timeout: return
	
	var did_something = false
	for item_type in immediate_items:
		handle_item(item_type)
		did_something = true
	
	if did_something:
		timeout()

func handle_item(item):
	match item:
		"spikes":
			# TO DO: slice us, temporarily disable any more reading of items
			pass

func timeout():
	on_timeout = true
	timeout_timer.wait_time = TIMEOUT_DURATION
	timeout_timer.start()

func _on_TimeoutTimer_timeout():
	on_timeout = false

func reset_immediate_items():
	immediate_items = []

#
# Ongoing items
# (once triggered, they stay with you for a while (like a powerup, that wears off eventually))
#
func _on_OngoingTimer_timeout():
	reset_ongoing_items()

func do_ongoing(type):
	pass

func undo_ongoing(type):
	pass

func reset_ongoing_items():
	for item in ongoing_items:
		undo_ongoing(item)
	
	ongoing_items = []

func start_ongoing_timer():
	ongoing_timer.wait_time = ITEM_EFFECT_DURATION
	ongoing_timer.start()
