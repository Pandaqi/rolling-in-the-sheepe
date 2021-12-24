extends CanvasLayer

onready var upper_cont = $Control
onready var cont = $Control/CenterContainer/VBoxContainer

var setting_module_scene = preload("res://scenes/settings/technical_settings_module.tscn")
var modules = []

var active : bool = false

func activate():
	create_interface()
	hide()

func _on_Main_open_settings():
	GAudio.play_static_sound("button")
	show()

func _input(ev):
	if ev.is_action_released("settings"): toggle()
	
	if not active and ev.is_action_released("quit"):
		get_tree().quit()

func _on_SettingsButton_pressed():
	toggle()

func _on_QuitButton_pressed():
	get_tree().quit()

func toggle():
	if not active: show()
	else: hide()

func hide():
	upper_cont.set_visible(false)
	get_tree().paused = false
	active = false
	
	for mod in modules:
		mod.release_focus()

func show():
	get_tree().paused = true
	
	upper_cont.set_visible(true)
	grab_focus_on_first()
	active = true

func grab_focus_on_first():
	modules[0].grab_focus_on_comp()

func create_interface():
	var st = GConfig.settings
	
	for i in range(st.size()):
		var cur_setting = st[i]
		var node = setting_module_scene.instance()
		
		# set correct name and section,
		# so it knows WHICH entries to update
		node.initialize(cur_setting)
		
		# set to the current saved value in the config
		node.update_to_config()
		
		# add the whole thing
		cont.add_child(node)
		modules.append(node)
	
	# make sure the back button is at the BOTTOM
	var back_btn = cont.get_node("Back")
	cont.remove_child(back_btn)
	cont.add_child(back_btn)

func _on_Back_pressed():
	GAudio.play_static_sound("button")
	self.hide()
