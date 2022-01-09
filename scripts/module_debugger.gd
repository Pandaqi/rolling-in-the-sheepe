extends Node2D

onready var label = $Label
onready var body = get_parent()

var active : bool = false

func _ready():
	active = GDict.cfg.debug_players
	set_visible(active)

func _physics_process(dt):
	if not active: return
	
	label.global_position = body.global_position + Vector2.UP*30
	label.global_rotation = 0
	
	label.get_node("Label").set_text(str(body.room_tracker.get_cur_room().route.index))
