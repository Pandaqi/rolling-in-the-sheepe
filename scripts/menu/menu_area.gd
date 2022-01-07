extends Area2D

export var type = "tutorial"
var players_here : int = 0

var preparing_load : bool = false
var load_timer : float = 0.0

const PREP_DURATION : float = 3.0

onready var helper_sprite = $Helper
onready var anim_player = $AnimationPlayer

func _on_Area2D_body_entered(body):
	if not body.is_in_group("Players"): return
	
	players_here += 1
	check_if_filled()

func _on_Area2D_body_exited(body):
	if not body.is_in_group("Players"): return
	players_here -= 1
	
	stop_preparing()

func stop_preparing():
	preparing_load = false
	load_timer = 0.0
	helper_sprite.modulate = Color(1,1,1,1)
	anim_player.stop(true)

func check_if_filled():
	var num_players = GInput.get_player_count()
	if players_here < num_players: return
	
	preparing_load = true
	anim_player.play("PreparingPlay")

func _physics_process(dt):
	if not preparing_load: return
	load_timer += dt
	
	if load_timer < PREP_DURATION: return
	finalize_load()

func finalize_load():
	G.load_game(type)
