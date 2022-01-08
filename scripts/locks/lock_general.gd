extends Node

var my_room
var coin_related : bool = false
var general_parameter
var gate_type = ""

onready var map = get_node("/root/Main/Map")
onready var feedback = get_node("/root/Main/Feedback")

signal delete()

func link_to_room(params):
	my_room = params.room
	
	if params.has('coin_related'):
		coin_related = params.coin_related

func on_body_enter(body):
	if coin_related: body.get_node("Coins").show()

func on_body_exit(body):
	pass

func set_sub_type(tp : String):
	pass

func is_invalid() -> bool:
	return false

# NOTE: Audio system works from nodes, but we want to give it a _position_ for the sound,
# so make a fake object for that
func create_audio_obj():
	return { 'global_position': my_room.rect.get_real_center() }

func on_progress():
	GAudio.play_dynamic_sound(create_audio_obj(), "lock_progress")

func perform_update():
	pass

func delete(hard_remove : bool = false):
	emit_signal("delete")
	self.queue_free()
	my_room.lock.remove_lock()
	
	# If this wasn't a deletion because the room is being deleted,
	# it must because the lock was unlocked
	# (should've been a much cleaner structure, but it is what it is)
	if not hard_remove:
		feedback.create_at_pos(my_room.rect.get_real_center(), "Unlocked!")
		my_room.main_particles.create_at_pos(my_room.rect.get_real_center(), "lock", { "spread_across": my_room })
		GAudio.play_dynamic_sound(create_audio_obj(), "lock_unlocked")
