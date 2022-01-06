extends CanvasLayer

onready var anim_player = $AnimationPlayer
onready var cont = $Container
onready var label = $Container/Label

var texts = [
	"Gotta roll with the punches, right?",
	"You can't sink any sheeper ...",
	"Sometimes, it's just the roll of a dice.",
	"Take a sheep, hard look at your playstyle ...",
	"Maybe next time?",
	"Try going faster ... without making mistakes!",
	"Tip: stay grounded for a while to get more round",
	"Tip: hold both buttons, while in the air, to float",
	"Tip: you can jump infinitely! (By pressing both your buttons.)",
	"Tip: with the right shape and speed, you can stick to ceilings",
	"Tip: play the game with (newbie) friends to make yourself feel better about your skills!"
]

func _ready():
# warning-ignore:return_value_discarded
	get_tree().get_root().connect("size_changed", self, "on_resize")
	on_resize()

func on_resize():
	var vp = get_viewport().size
	cont.set_position(0.5*vp)

func activate():
	anim_player.play("MenuReveal")
	label.set_text(select_random_text())

func select_random_text():
	return texts[randi() % texts.size()]
