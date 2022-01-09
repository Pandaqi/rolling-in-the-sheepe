extends Node2D

onready var my_item = get_parent()
onready var anim_player = $AnimationPlayer

# Animated = constant speed, slows down
# Burst = sudden bursts to quarter angles
var type : String = ""

func _ready():
	var type = "animated"
	if randf() <= 0.5: type = "burst"
	
	if type == "animated":
		if randf() <= 0.5:
			anim_player.play("PlatformRotate")
		else:
			anim_player.play("PlatformRotateBackwards")
	else:
		if randf() <= 0.5:
			anim_player.play("BurstRotate")
		else:
			anim_player.play_backwards("BurstRotate")

func _on_Timer_timeout():
	anim_player.playback_speed *= 0.875
	
	if anim_player.playback_speed < 0.15:
		my_item.remove_module()
