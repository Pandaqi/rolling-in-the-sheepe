extends CanvasLayer

onready var anim_player = $AnimationPlayer
onready var cont = $Container
var phase : String = "idle"
var active : bool = false

func _ready():
# warning-ignore:return_value_discarded
	get_tree().get_root().connect("size_changed", self, "on_resize")
	on_resize()

func disable():
	self.queue_free()

func on_resize():
	var vp = get_viewport().size
	cont.set_position(0.5*vp)

func show_menu():
	GAudio.play_static_sound("ui_button_press")
	
	get_tree().paused = true
	active = true
	phase = "showing"
	anim_player.play("MenuReveal")

func hide_menu():
	GAudio.play_static_sound("ui_button_press")
	
	phase = "hiding"
	anim_player.play_backwards("MenuReveal")

func _on_AnimationPlayer_animation_finished(_anim_name):
	if phase == "hiding":
		get_tree().paused = false
		active = false
		phase = "idle"

func _input(ev):
	if phase == "idle":
		if ev.is_action_released("ui_pause"):
			show_menu()
			return
	
	if not active: return
	if phase == "hiding": return

	if ev.is_action_released("ui_restart"):
		G.restart()
	elif ev.is_action_released("ui_resume"):
		hide_menu()
	elif ev.is_action_released("ui_exit"):
		G.back_to_menu()
