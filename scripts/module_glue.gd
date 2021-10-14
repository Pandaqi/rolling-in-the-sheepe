extends Node2D

# NOTE: "_active" is a permanent state
#       "_disabled" simply means it's temporarily not available (because it was recently used)
var glue_active : bool = false
var glue_disabled : bool = false

var spikes_active : bool = false
var spikes_disabled : bool = false

var is_wolf : bool = false

var player_num : int = -1

onready var player_progression = get_node("/root/Main/Map/PlayerProgression")

onready var body = get_parent()
onready var slicer = get_node("/root/Main/Slicer")
onready var shaper = get_node("../Shaper")

func set_player_num(num):
	player_num = num

func make_wolf():
	is_wolf = true

func make_sheep():
	is_wolf = false

func _physics_process(_dt):
	check_glue()
	check_spikes()

#
# Glue
#
func check_glue():
	if not glue_active: return
	if glue_disabled: return
	
	for obj in body.contact_data:
		var other_body = obj.body
		
		if not other_body.is_in_group("Players"): continue
		if other_body.get_node("Status").player_num != player_num: continue
		
		glue_object_to_me(obj)
		break

func glue_object_to_me(obj):
	var num_shapes = obj.body.shape_owner_get_shape_count(0)
	for i in range(num_shapes):
		var shape = obj.body.shape_owner_get_shape(0, i)
		var points = obj.body.get_node("Shaper").make_global(Array(shape.points))
		var local_points = shaper.make_local_external(points)
		shaper.append_shape(local_points)
	
	obj.body.get_node("Glue").disable_glue()
	obj.body.queue_free()
	player_progression.on_body_sliced(obj.body)
	
	disable_glue()

func disable_glue():
	glue_disabled = true
	$GlueTimer.start()

func _on_GlueTimer_timeout():
	glue_disabled = false

#
# Spikes
#
func check_spikes():
	if not spikes_active and not is_wolf: return
	if spikes_disabled: return
	
	for obj in body.contact_data:
		var other_body = obj.body
		
		if not other_body.is_in_group("Players"): continue
		if other_body.get_node("Status").player_num == player_num: continue
		
		spike_object(obj)
		break

func spike_object(obj):
	var extended_normal = -obj.normal * 100
	var start = obj.pos - extended_normal
	var end = obj.pos + extended_normal
	
	slicer.slice_bodies_hitting_line(start, end, [obj.body])

	slicer.start_point = start
	slicer.end_point = end
	slicer.update()
	
	disable_spikes()

func disable_spikes():
	spikes_disabled = true
	$SpikeTimer.start()

func _on_SpikeTimer_timeout():
	spikes_disabled = false
