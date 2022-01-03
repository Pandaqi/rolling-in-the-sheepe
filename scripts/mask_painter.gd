extends Node

var surface_image : Image = Image.new()
var surface_texture : ImageTexture = ImageTexture.new()

var paint_image : Image = preload("res://assets/paint_mask.png")

var image_size : Vector2
var resolution : float = 1.5

var active : bool = true
var dirty : bool = true

onready var player_manager = get_node("/root/Main/PlayerManager")
onready var cam = get_node("/root/Main/Camera2D")
onready var map = get_parent()

func _ready():
	if not GDict.cfg.paint_on_tilemap:
		active = false
		return
	
	create_mask_texture()

func create_mask_texture():
	var world_size : Vector2 = map.WORLD_SIZE * map.TILE_SIZE
	
	image_size = (world_size / resolution).floor()
	surface_image.create(int(image_size.x), int(image_size.y), false,Image.FORMAT_RGBAH)

	$Sprite.texture = surface_texture
	$Sprite.set_scale(Vector2.ONE * resolution)

func set_texture_size(new_size):
	$TilemapTexture.size = new_size

func out_of_mask_bounds(pos):
	return pos.x < 0 or pos.x >= image_size.x or pos.y < 0 or pos.y >= image_size.y

func _physics_process(_dt):
	if not active: return
	if not dirty: return
	
	surface_texture.create_from_image(surface_image)
	dirty = false

func clear_mask():
	if not active: return
	surface_image.lock()
	surface_image.fill(Color(0,0,0,0))
	surface_image.unlock()
	
	dirty = true

# REMEMBER: when working with these images/texture, only INTEGER coordinates are allowed!
func clear_rectangle(pos, size):
	if not active: return
	
	surface_image.lock()
	
	var conv_pos = pos / resolution
	var conv_size = size / resolution

	pos = conv_pos.floor()
	size = conv_size.floor()
	
	var img = Image.new()
	img.create(size.x, size.y, false, Image.FORMAT_RGBAH)
	img.fill(Color(0,0,0,0))
	
	surface_image.blit_rect(img, Rect2(Vector2.ZERO, size), pos)
	
	surface_image.unlock()
	
	dirty = true

func paint_on_mask(pos : Vector2, player_num : int):
	if not active: return
	
	surface_image.lock()
	
	var conv_pos = pos / resolution
	
	# place pixels in the form of a circle
	# we do it this way, because it allows us to 
	#  => customize COLOR
	#  => customize SIZE
	#  => keep ALPHA intact
	var radius = 8 + randi() % 8
	var col = player_manager.player_colors[player_num]
	for x in range(-radius,radius):
		for y in range(-radius,radius):
			if Vector2(x,y).length() > radius: continue
			
			var temp_pos = conv_pos + Vector2(x,y)
			if out_of_mask_bounds(temp_pos): continue
			
			surface_image.set_pixelv(temp_pos, col)
	
	surface_image.unlock()
	
	dirty = true
