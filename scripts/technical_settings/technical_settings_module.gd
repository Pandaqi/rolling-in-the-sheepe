extends VBoxContainer

var sec = "" 
var nm = ""
var comp = ""

var cont

func initialize(setting):
	sec = setting.sec
	nm = setting.name
	comp = setting.comp
	
	cont = get_node("HBoxContainer")
	
	# set label
	cont.get_node("Label").set_text(setting.label)
	
	# only keep the correct interface element
	for child in cont.get_children():
		if child.name == "Label" or child.name == comp:
			continue
		
		child.queue_free()
	
	# if it has a description, set it
	# otherwise, remove
	if setting.has('desc'):
		get_node("Desc").set_text(setting.desc)
	else:
		get_node("Desc").queue_free()
	
	# if it has a custom range, set it
	if setting.has('range'):
		var slider = cont.get_node("HSlider")
		
		slider.min_value = setting.range.min
		slider.max_value = setting.range.max
		
		slider.step = (setting.range.min + setting.range.max) / 50.0

func grab_focus_on_comp():
	cont.get_node(comp).grab_focus()

func update_to_config():
	var val = GConfig.get_config_val(sec, nm)

	if comp == "HSlider":
		cont.get_node(comp).value = val
	elif comp == "Checkbox":
		cont.get_node(comp).pressed = val

func _on_HSlider_value_changed(value):
	if not G.is_mobile(): GAudio.play_static_sound("button")
	GConfig.update_config_val({ "sec": sec, "name": nm}, value)

func _on_Checkbox_toggled(button_pressed):
	GAudio.play_static_sound("button")
	GConfig.update_config_val({ "sec": sec, "name": nm}, button_pressed)
