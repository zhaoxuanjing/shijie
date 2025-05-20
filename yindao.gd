extends Control

func _ready():
	# Start the animation when the scene loads
	$Label.modulate.a = 0
	var tween = create_tween()
	tween.tween_property($Label, "modulate:a", 1.0, 2.0)  # Slower fade in
	tween.tween_interval(8.0)  # Longer display time for reading
	tween.tween_property($Label, "modulate:a", 0.0, 2.0)  # Slower fade out
	tween.tween_callback(func(): get_tree().change_scene_to_file("res://场景/场景一/world.tscn")) 
