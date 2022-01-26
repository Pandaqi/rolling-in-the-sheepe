extends Node2D

var sprite_size : float = 256.0
var scale_bump : float = 1.33

onready var animation_player = $AnimationPlayer
onready var shield = $Shield
onready var shield_anim_player = $Shield/AnimationPlayer

var shaper
var face_sprite
var ear_sprite

func _module_ready():
	shield.set_visible(false)

func link_sprites():
	face_sprite = $FaceSprite
	shaper = get_node("../Shaper")
	ear_sprite = shaper.get_node("EarSprite")

func update_size(_bounds):
	if not face_sprite: link_sprites()
	
	var new_scale = shaper.approximate_radius()/sprite_size * scale_bump
	face_sprite.set_scale(Vector2(1,1)*new_scale)
	
	# TO DO: show this BEHIND the Shaper, but I see no easy way to set those Z-indices
	ear_sprite.set_scale(Vector2(1,1)*new_scale)

func make_wolf():
	face_sprite.set_frame(0)
	ear_sprite.set_frame(0)
	
	animation_player.play("WolfHighlight")

func make_sheep():
	face_sprite.set_frame(1)
	ear_sprite.set_frame(1)
	
	animation_player.stop(true)

func make_invincible():
	shield.set_visible(true)
	shield_anim_player.play("ShieldFlicker")

func make_vincible():
	shield.set_visible(false)
	shield_anim_player.stop()
