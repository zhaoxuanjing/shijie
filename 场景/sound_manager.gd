extends Node

enum Bus { MASTER, SFX, BGM }

@onready var sfx: Node = $SFX
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer

func play_sfx(name: String) -> void:
	# Handle case sensitivity for sound names
	var node_name := name
	if name.to_lower() == "jump":
		node_name = "Jump"
	elif name.to_lower() == "attack":
		node_name = "Attack"
	elif name.to_lower() == "uipress":
		node_name = "UIPress"
	elif name.to_lower() == "uifocus":
		node_name = "UIFocus"
	elif name.to_lower() == "save":
		node_name = "Save"
	
	var player := sfx.get_node(node_name) as AudioStreamPlayer
	if not player:
		return
	player.play()


func play_bgm(stream: AudioStream) -> void:
	if bgm_player.stream == stream and bgm_player.playing:
		return
	bgm_player.stream = stream
	bgm_player.play()


func setup_ui_sounds(node: Node) -> void:
	var button := node as Button
	if button:
		if not button.pressed.is_connected(play_sfx.bind("UIPress")):
			button.pressed.connect(play_sfx.bind("UIPress"))
		if not button.focus_entered.is_connected(play_sfx.bind("UIFocus")):
			button.focus_entered.connect(play_sfx.bind("UIFocus"))
		if not button.mouse_entered.is_connected(button.grab_focus):
			button.mouse_entered.connect(button.grab_focus)
	
	var slider := node as Slider
	if slider:
		if not slider.value_changed.is_connected(play_sfx.bind("UIPress").unbind(1)):
			slider.value_changed.connect(play_sfx.bind("UIPress").unbind(1))
		if not slider.focus_entered.is_connected(play_sfx.bind("UIFocus")):
			slider.focus_entered.connect(play_sfx.bind("UIFocus"))
		if not slider.mouse_entered.is_connected(slider.grab_focus):
			slider.mouse_entered.connect(slider.grab_focus)
	
	for child in node.get_children():
		setup_ui_sounds(child)


func get_volume(bus_index: int) -> float:
	var db := AudioServer.get_bus_volume_db(bus_index)
	return db_to_linear(db)


func set_volume(bus_index: int, v: float) -> void:
	var db := linear_to_db(v)
	AudioServer.set_bus_volume_db(bus_index, db)
