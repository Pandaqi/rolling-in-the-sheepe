extends Camera2D

var default_vp = Vector2(1024, 600)

func _ready():
# warning-ignore:return_value_discarded
	get_tree().get_root().connect("size_changed", self, "on_resize")
	on_resize()

func on_resize():
	var vp = get_viewport().size
	
	var zoom_per_axis = default_vp / vp
	var final_zoom = max(zoom_per_axis.x, zoom_per_axis.y)

	zoom = Vector2.ONE * final_zoom
	position = 0.5*default_vp
