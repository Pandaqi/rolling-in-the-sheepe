extends Node2D

var sprite_size : float = 256.0

onready var animation_player = $AnimationPlayer
onready var face_sprite = $FaceSprite
onready var ear_sprite = get_node("../Shaper/EarSprite")

func link_sprites():
	face_sprite = $FaceSprite
	ear_sprite = get_node("../Shaper/EarSprite")

func update_size(bounds):
	if not face_sprite: link_sprites()
	
	var x_size = abs(bounds.x.min) + abs(bounds.x.max)
	var y_size = abs(bounds.y.min) + abs(bounds.y.max)
	var max_size = max(x_size, y_size)
	
	var new_scale = max_size/sprite_size
	face_sprite.set_scale(Vector2(1,1)*new_scale)
	
	# TO DO: show this BEHIND the Shaper, but I see no easy way to set those Z-indices
	ear_sprite.set_scale(Vector2(1,1)*new_scale)

func make_wolf():
	face_sprite.set_frame(1)
	ear_sprite.set_frame(1)
	
	animation_player.play("WolfHighlight")

func make_sheep():
	face_sprite.set_frame(0)
	ear_sprite.set_frame(0)
	
	animation_player.stop(true)
