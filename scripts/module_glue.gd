extends Node

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
onready var rounder = get_node("../Rounder")

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
	
	var unrealistic_glueing = GlobalDict.cfg.unrealistic_glueing
	
	for obj in body.contact_data:
		var other_body = obj.body
		
		if not other_body.is_in_group("Players"): continue
		if other_body.get_node("Status").player_num != player_num: continue
		
		if unrealistic_glueing:
			eat_and_grow_object(obj)
		else:
			glue_object_to_me(obj)
		break

func eat_and_grow_object(obj):
	var their_area : float = obj.body.get_node("Shaper").get_area()
	var our_area : float = shaper.get_area()
	
	# if they are bigger than us, they should eat us
	# and they will, because a collision goes both ways
	if their_area > our_area: return
	
	obj.body.get_node("Status").delete()
	
	var grow_ratio = 2.0 * (our_area / their_area - 1.0)
	rounder.grow(grow_ratio)

func glue_object_to_me(obj):
	var num_shapes = obj.body.shape_owner_get_shape_count(0)
	for i in range(num_shapes):
		var shape = obj.body.shape_owner_get_shape(0, i)
		var points = obj.body.get_node("Shaper").make_global(Array(shape.points))
		var local_points = shaper.make_local_external(points)
		shaper.append_shape(local_points)
	
	obj.body.get_node("Status").delete()
	
	var extra_coins = obj.body.get_node("Coins").count()
	get_node("Coins").get_paid(extra_coins)

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
		
		if GlobalDict.cfg.wolf_takes_coin:
			if is_wolf and other_body.get_node("Coins").has_some():
				other_body.get_node("Coins").pay(1)
				body.coins.get_node("Coins").get_paid(1)
				break
		
		spike_object(obj)
		break

func get_realistic_slice_line(obj):
	var extended_normal = -obj.normal * 100
	var start = obj.pos - extended_normal
	var end = obj.pos + extended_normal
	
	# DEBUGGING
	slicer.start_point = start
	slicer.end_point = end
	slicer.update()
	
	return { 'start': start, 'end': end }

func get_halfway_slice_line(other_body):
	#var bb = body.get_node("Shaper").bounding_box
	
	var center_pos = other_body.get_global_position()
	var start = center_pos - 100*Vector2(1,1)
	var end = center_pos + 100*Vector2(1,1)
	
	# DEBUGGING
	slicer.start_point = start
	slicer.end_point = end
	slicer.update()
	
	return { 'start': start, 'end': end }

func slice_along_halfway_line():
	var slice_line = get_halfway_slice_line(body)
	slicer.slice_bodies_hitting_line(slice_line.start, slice_line.end, [body])

func spike_object(obj):
	var slice_line = get_realistic_slice_line(obj)
	if is_wolf: 
		slice_line = get_halfway_slice_line(obj.body)
	
	slicer.slice_bodies_hitting_line(slice_line.start, slice_line.end, [obj.body])
	
	disable_spikes()

func disable_spikes():
	spikes_disabled = true
	$SpikeTimer.start()

func _on_SpikeTimer_timeout():
	spikes_disabled = false
