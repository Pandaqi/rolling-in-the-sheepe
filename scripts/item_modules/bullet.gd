extends Area2D

var vel
var dist_traveled : float = 0.0
const MAX_DIST : float = 400.0

func set_starting_velocity(v : Vector2):
	vel = v

func _physics_process(dt):
	set_rotation(vel.angle())
	
	var final_vec = vel*dt
	position += final_vec
	dist_traveled += final_vec.length()

	if dist_traveled > MAX_DIST:
		self.queue_free()

func _on_Area2D_body_entered(body):
	if not body.is_in_group("Players"): return
	if body.status.is_invincible: return
	
	GAudio.play_dynamic_sound(barrel_tip, "bullet_hit")
	body.glue.call_deferreed("slice_along_halfway_line")
	body.coins.pay_half()
	
	self.queue_free()

