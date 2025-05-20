extends Control



func _on_animation_player_animation_finished(anim_name):
	if anim_name == "开机" :
		get_tree().change_scene_to_file("res://场景/t_itle_screen.tscn")
