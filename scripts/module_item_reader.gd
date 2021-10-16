extends Node

const ITEM_EFFECT_DURATION : float = 5.0
const TIMEOUT_DURATION : float = 1.0

onready var body = get_parent()
onready var status = get_node("../Status")
onready var glue = get_node("../Glue")

onready var slicer = get_node("/root/Main/Slicer")

onready var map = get_node("/root/Main/Map")

onready var ongoing_timer = $OngoingTimer
onready var timeout_timer = $TimeoutTimer

var immediate_items = []
var ongoing_items = []

var is_bomb : bool = false
var on_timeout : bool = false

func _physics_process(_dt):
	if status.is_invincible: return
	
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
	var grid_pos = map.get_grid_pos(obj.pos - 0.5*obj.normal*map.TILE_SIZE)
	if map.out_of_bounds(grid_pos): return
	
	var cell = map.get_cell(grid_pos)
	if is_bomb:
		map.explode_cell(body, cell)
		return
	
	if not cell.special: return
	var type = cell.special.type
	
	var reject_by_invincibility = (status.is_invincible and GlobalDict.item_types[type].has('invincibility'))
	if reject_by_invincibility: return
	
	var already_registered_cell = false
	for item in immediate_items:
		if (item.pos - grid_pos).length() <= 0.3:
			already_registered_cell = true
			break
	
	if already_registered_cell: return

	var coming_from_wrong_side = false
	var item_rot = cell.special.rotation
	var item_vec = Vector2(cos(item_rot), sin(item_rot))
	var our_vec = (body.get_global_position() - obj.pos).normalized()
	coming_from_wrong_side = our_vec.dot(item_vec) <= 0
	
	if coming_from_wrong_side: return
	
	var better_obj = {
		'pos': grid_pos,
		'type': type,
		'item': cell.special,
		'col_data': obj
	}
	
	if map.special_elements.type_is_immediate(type):
		immediate_items.append(better_obj)
	else:
		ongoing_items.append(better_obj)
		do_ongoing(better_obj)

#
# Immediate items
# (these are triggered every frame you touch them, immediately, and then reset at the end of the frame)
#
func do_something_with_items():
	if on_timeout: return
	
	var did_something = false
	for obj in immediate_items:
		handle_item(obj)
		did_something = true
	
	if did_something:
		timeout()

func handle_item(obj):
	var type = obj.type
	
	match type:
		"spikes":
			var slice_line = glue.get_realistic_slice_line(obj.col_data)
			slicer.slice_bodies_hitting_line(slice_line.start, slice_line.end, [body])
	
	map.special_elements.delete_on_activation(obj.item)

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

func do_ongoing(obj):
	pass

func undo_ongoing(obj):
	pass

func reset_ongoing_items():
	for item in ongoing_items:
		undo_ongoing(item)
	
	ongoing_items = []

func start_ongoing_timer():
	ongoing_timer.wait_time = ITEM_EFFECT_DURATION
	ongoing_timer.start()

func make_bomb():
	is_bomb = true

func undo_bomb():
	is_bomb = false
