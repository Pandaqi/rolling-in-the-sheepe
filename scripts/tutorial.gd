extends Node2D

const MAX_EXHAUSTIONS_BEFORE_SWITCH : int = 0
const MAX_USAGE_BEFORE_SWITCH : int = 5

var active : bool = true

var forced_dir : int = 0
var num_exhaustions : int = 0
var num_matches : int = 0
var forced_dir_has_matched : bool = false

var wanted_tutorial_placement : String = ""

onready var tilemap = get_node("/root/Main/Map/TileMap")

var tutorial_sprite = preload("res://scenes/ui/tutorial_sprite.tscn")

func _ready():
	disable()

func disable():
	active = false
	forced_dir = -1

func is_active():
	return active

# NOTE: We don't destroy this when done with the tutorial,
# as there are many references to it and
# it's much cleaner to NOT have to check "does the tutorial still exist?" each time
func finish():
	active = false

func get_forced_dir():
	return forced_dir

func record_forced_dir_match():
	forced_dir_has_matched = true
	num_matches += 1
	
	if MAX_USAGE_BEFORE_SWITCH >= 0:
		if num_matches > MAX_USAGE_BEFORE_SWITCH:
			perform_switch()

func forced_dir_exhausted():
	num_exhaustions += 1
	
	if not forced_dir_has_matched: return
	
	if num_exhaustions >= MAX_EXHAUSTIONS_BEFORE_SWITCH:
		perform_switch()

func perform_switch():
	forced_dir = (forced_dir + 2) % 4
	num_exhaustions = 0
	num_matches = 0
	forced_dir_has_matched = false
	
	print("Switched forced dir to " + str(forced_dir))
	
	if forced_dir == 0:
		print("Removed forced dir")
		forced_dir = -1
		wanted_tutorial_placement = "jump"

func placed_a_new_room(rect):
	if not wanted_tutorial_placement: return
	
	# TO DO: Look at the SIZE of the rect (and perhaps if it has a LOCK/TERRAIN), and use that to determine if we can place a tutorial here
	var can_place_it = false
	if not can_place_it: return
	
	place_image(rect)

# TO DO: use an ARRAY to loop through images in order, instead of hardcoding it, so I can allow ANY level to have a specific set of tutorials
func place_image(rect):
	var sprite = tutorial_sprite.instance()
	sprite.set_scale(Vector2(1,1))
	var new_tut = wanted_tutorial_placement
	
	if new_tut == "jump":
		sprite.set_frame(10)
	elif new_tut == "finish":
		sprite.set_frame(11)
	
	sprite.set_position(rect.get_center())
	tilemap.add_child(sprite)
	
	wanted_tutorial_placement = ""
	if new_tut == "jump":
		wanted_tutorial_placement = "finish"
	elif new_tut == "finish":
		finish()
