extends Control
@onready var v: VBoxContainer = $v
@onready var new_game: Button = $v/NewGame
@onready var load_game: Button = $v/LoadGame

func _ready() -> void:
	load_game.disabled = not Game.has_save()
	
	new_game.grab_focus()
	for button: Button in v.get_children():
		button.mouse_entered.connect(button.grab_focus)
	
	
	SoundManager.setup_ui_sounds(self)
	SoundManager.play_bgm(preload("res://总素材/bgm/02 1 titles LOOP.mp3"))

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://yindao.tscn")

func _on_load_game_pressed() -> void:
	Game.load_game()


func _on_exit_game_pressed() -> void:
	get_tree().quit()
