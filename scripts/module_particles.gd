extends Node2D

const NUM_SPRITES_IN_RING : int = 8
const SPRITE_SCALE : float = 0.25
const RADIUS_INCREASE : float = 2.25

const MIN_DIST_FOR_MOVING : float = 2.0

var last_particle_pos : Vector2 = Vector2.ZERO

var ring_sprites = []
onready var part = $Particles2D
onready var part_ring = $ParticleRing
onready var body = get_parent()

onready var float_particles = $FloatParticles

func _module_ready():
	end_float()

func prepare_ring():
	part_ring = $ParticleRing
	
	var delta_ang = 2*PI / float(NUM_SPRITES_IN_RING)
	var ang = 0
	for i in range(NUM_SPRITES_IN_RING):
		var s = Sprite.new()
		s.set_scale(Vector2.ONE * SPRITE_SCALE)
		s.set_rotation(ang)
		
		ang += delta_ang
		
		part_ring.add_child(s)
		ring_sprites.append(s)
	
	update_radius()

func _physics_process(dt):
	var cur_pos = body.global_position
	var standstill = (cur_pos - last_particle_pos).length() < MIN_DIST_FOR_MOVING*dt
	part.set_emitting(not standstill)
	last_particle_pos = cur_pos

func update_radius(rad : float = 1.0):
	if ring_sprites.size() <= 0: prepare_ring()
	
	# we want them to appear OUTSIDE the body, not near/on the edge
	# so increase the radius
	var actual_radius = rad * RADIUS_INCREASE
	for i in range(NUM_SPRITES_IN_RING):
		var s = ring_sprites[i]
		var ang = s.rotation
		s.set_position(Vector2(cos(ang), sin(ang)) * actual_radius)

func create_ring(tp : String):
	var tex = load("res://assets/particles/particle_" + tp + ".png")
	for child in part_ring.get_children():
		child.set_texture(tex)
	
	part_ring.set_visible(true)

func remove_ring():
	part_ring.set_visible(false)

func start_float():
	float_particles.set_emitting(true)

func end_float():
	float_particles.set_emitting(false)
