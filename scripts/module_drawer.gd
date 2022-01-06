extends Node2D

onready var body = get_parent()

onready var actual_drawer = $ActualDrawer
onready var tween = $Tween
onready var float_anim = $AnimationPlayer

func update_shape():
	get_node("ActualDrawer").update_shape(get_parent())
	if tween: play_pop_tween()

func set_color(c):
	get_node("ActualDrawer").set_color(c)

func squash(normal : Vector2):
	if tween.is_active(): return
	
	# The squash trick!
	# The container rotates so that it _matches_ the normal
	#    (don't forget we also need to accomodate for parent rotation)
	# Then the actual drawer counter rotates so, visually, it stays identical
	# Now we can just squash the X-axis and we're good!
	var top_angle = normal.angle() - body.get_rotation()
	
	self.transform = Transform2D(top_angle, self.position)
	actual_drawer.transform = Transform2D(-top_angle, actual_drawer.position)
	
	var down_scale = Vector2(0.8,1.2)
	var full_scale = Vector2.ONE
	var dur = 0.05
	
	tween.interpolate_property(self, "scale",
		full_scale, down_scale, dur,
		Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.interpolate_property(self, "scale",
		down_scale, full_scale, dur,
		Tween.TRANS_LINEAR, Tween.EASE_OUT,
		dur)
	tween.start()

func play_pop_tween():
	var start = Vector2.ONE
	var end = Vector2.ONE*1.5
	var dur = 0.1
	
	set_scale(start)
	
	tween.interpolate_property(self, "scale",
		start, end, dur,
		Tween.TRANS_LINEAR, Tween.EASE_OUT)
	tween.interpolate_property(self, "scale",
		end, start, dur,
		Tween.TRANS_LINEAR, Tween.EASE_OUT,
		dur)
	tween.start()

func start_float():
	float_anim.play("FloatAnim")

func end_float():
	float_anim.stop(true)
	modulate = Color(1,1,1)
