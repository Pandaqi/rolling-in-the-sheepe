extends Node

# NOTE: "_active" is a permanent state
#       "_disabled" simply means it's temporarily not available (because it was recently used)
var glue_active : bool = false
var glue_disabled : bool = false
var use_glue_area : bool = false

var spikes_active : bool = false
var spikes_disabled : bool = false

var is_wolf : bool = false

var player_num : int = -1

onready var body = get_parent()

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
		var res = glue_if_valid(other_body)
		if res: break

func glue_if_valid(b):
	if not b.is_in_group("Players"): return false
	if b.status.player_num != player_num: return false
	if b == body: return false #its ourselves => would really like a better way to prevent this beforehand
	if body.status.is_dead or b.status.is_dead: return false
	
	var unrealistic_glueing = GDict.cfg.unrealistic_glueing
	
	if unrealistic_glueing:
		eat_and_grow_object(b)
	else:
		glue_object_to_me(b)
	
	return true

func eat_and_grow_object(b):
	var their_area : float = b.shaper.get_area()
	var our_area : float = body.shaper.get_area()
	
	b.status.delete()
	
	var grow_ratio = ((our_area + their_area) / their_area) - 1.0
	body.rounder.grow(grow_ratio)

func glue_object_to_me(b):
	var num_shapes = b.shape_owner_get_shape_count(0)
	for i in range(num_shapes):
		var shape = b.shape_owner_get_shape(0, i)
		var points = b.shaper.make_global(Array(shape.points))
		var local_points = body.shaper.make_local_external(points)
		body.shaper.append_shape(local_points)
	
	b.status.delete()
	
	var extra_coins = b.coins.count()
	body.coins.get_paid(extra_coins)

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
		if other_body.status.player_num == player_num: continue
		if other_body.status.is_invincible: continue
		
		if GDict.cfg.wolf_takes_coin:
			if is_wolf and other_body.coins.has_some():
				other_body.coins.pay(1)
				body.coins.get_paid(1)
				other_body.status.make_invincible()
				break
		
		spike_object(obj)
		break

func get_realistic_slice_line(obj):
	var extended_normal = -obj.normal * 100
	var start = obj.pos - extended_normal
	var end = obj.pos + extended_normal
	
	return { 'start': start, 'end': end }

func get_halfway_slice_line(other_body):
	#var bb = body.shaper.bounding_box
	
	var center_pos = other_body.get_global_position()
	var start = center_pos - 100*Vector2(1,1)
	var end = center_pos + 100*Vector2(1,1)
	
	return { 'start': start, 'end': end }

func slice_along_halfway_line():
	var slice_line = get_halfway_slice_line(body)
	body.slicer.slice_bodies_hitting_line(slice_line.start, slice_line.end, [body])

func spike_object(obj):
	if obj.body.status.is_invincible: return
	
	var slice_line = get_realistic_slice_line(obj)
	if is_wolf: 
		slice_line = get_halfway_slice_line(obj.body)
	
	body.slicer.slice_bodies_hitting_line(slice_line.start, slice_line.end, [obj.body])
	
	disable_spikes()

func disable_spikes():
	spikes_disabled = true
	$SpikeTimer.start()

func _on_SpikeTimer_timeout():
	spikes_disabled = false
